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

    # Picks the address with the configured suffix.
    dualstack = {
      imports = [ client ];
      security.pki.certificateFiles = [ "${certs}/ca.crt" ];
      networking.interfaces.eth1.ipv6.addresses = [
        {
          address = "2001:db8:1::243";
          prefixLength = 64;
        }
      ];
      services.duckdns.ipv6 = {
        enable = true;
        interface = "eth1";
        addressSuffix = "::243";
      };
    };

    # Picks the first suitable address.
    ipv6only = {
      imports = [ client ];
      security.pki.certificateFiles = [ "${certs}/ca.crt" ];
      services.duckdns = {
        ipv4.enable = false;
        ipv6 = {
          enable = true;
          interface = "eth1";
        };
      };
    };
  };

  testScript =
    { nodes, ... }:
    let
      requests = node: "grep -F '${node.networking.primaryIPAddress} ' /var/log/nginx/access.log";
      update = "GET /update?verbose=true&domains=foo,bar&token=test-token";
    in
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

      # ULA, deprecated and suffix-mismatching addresses must be skipped.
      def add_decoy_addresses(machine):
          machine.succeed(
              "ip -6 addr add fd00::243/64 dev eth1 nodad",
              "ip -6 addr add 2001:db8:2::243/64 dev eth1 nodad preferred_lft 0",
          )
          machine.log(machine.succeed("ip -6 addr show dev eth1"))

      with subtest("IPv4 and IPv6 are updated separately"):
          dualstack.wait_for_unit("multi-user.target")
          add_decoy_addresses(dualstack)
          dualstack.succeed("systemctl start --wait duckdns.service")
          server.succeed("${requests nodes.dualstack} | grep -F '${update}&ip= '")
          server.succeed("${requests nodes.dualstack} | tail -n1 | grep -F '${update}&ipv6=2001:db8:1::243 '")

      with subtest("only IPv6 is updated if IPv4 is disabled"):
          ipv6only.wait_for_unit("multi-user.target")
          add_decoy_addresses(ipv6only)
          ipv6only.succeed("systemctl start --wait duckdns.service")
          server.succeed(
              "${requests nodes.ipv6only} | tail -n1"
              " | grep -F '${update}&ipv6=${nodes.ipv6only.networking.primaryIPv6Address} '"
          )
          server.fail("${requests nodes.ipv6only} | grep -F '&ip='")
    '';
}
