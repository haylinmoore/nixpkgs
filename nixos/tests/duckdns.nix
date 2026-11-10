{ lib, pkgs, ... }:
let
  certs = pkgs.runCommand "duckdns-test-certs" { nativeBuildInputs = [ pkgs.openssl ]; } ''
    mkdir $out
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 36500 \
      -subj "/CN=DuckDNS Test CA" -keyout $out/ca.key -out $out/ca.crt
    openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
      -subj "/CN=www.duckdns.org" -keyout $out/server.key -out server.csr
    openssl x509 -req -in server.csr -days 36500 -CA $out/ca.crt -CAkey $out/ca.key \
      -extfile <(echo "subjectAltName=DNS:www.duckdns.org") -out $out/server.crt
  '';

  client =
    { nodes, ... }:
    {
      networking.hosts.${nodes.server.networking.primaryIPAddress} = [ "www.duckdns.org" ];
      services.duckdns = {
        enable = true;
        tokenFile = pkgs.writeText "duckdns-token" "test-token";
        domains = [
          "foo"
          "bar"
        ];
      };
    };
in
{
  name = "duckdns";
  meta.maintainers = with lib.maintainers; [ haylin ];

  nodes = {
    server = {
      networking.firewall.allowedTCPPorts = [ 443 ];
      services.nginx = {
        enable = true;
        virtualHosts."www.duckdns.org" = {
          onlySSL = true;
          sslCertificate = "${certs}/server.crt";
          sslCertificateKey = "${certs}/server.key";
          locations."= /update".return = ''200 "OK\n1.2.3.4\n\nUPDATED\n"'';
        };
      };
    };

    client = {
      imports = [ client ];
      security.pki.certificateFiles = [ "${certs}/ca.crt" ];
    };

    untrusted = client;
  };

  testScript =
    { nodes, ... }:
    ''
      start_all()
      server.wait_for_unit("nginx.service")
      server.wait_for_open_port(443)

      with subtest("update succeeds against a trusted server"):
          client.wait_for_unit("multi-user.target")
          client.succeed("systemctl start --wait duckdns.service")
          server.succeed(
              "grep -F '${nodes.client.networking.primaryIPAddress} ' /var/log/nginx/access.log"
              " | grep -F 'GET /update?verbose=true&domains=foo,bar&token=test-token&ip= '"
          )

      with subtest("update fails if the certificate is not trusted"):
          untrusted.wait_for_unit("multi-user.target")
          untrusted.fail("systemctl start --wait duckdns.service")
          server.fail("grep -F '${nodes.untrusted.networking.primaryIPAddress} ' /var/log/nginx/access.log")
    '';
}
