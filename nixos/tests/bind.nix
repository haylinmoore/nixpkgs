{ ... }:
{
  name = "bind";

  nodes.machine =
    { pkgs, lib, ... }:
    let
      commonSoa = {
        nameServer = "ns1";
        adminEmail = "admin";
        serial = 1;
        refresh = "3h";
        retry = "1h";
        expire = "1w";
        negativeCacheTtl = "1d";
      };
    in
    {
      environment.systemPackages = [ pkgs.dnsutils ];
      services.bind.enable = true;
      services.bind.extraOptions = "empty-zones-enable no;";
      services.bind.zones = [
        {
          name = "example.org";
          master = true;
          file = pkgs.writeText "example.org.zone" ''
            $TTL 3600
            example.org. IN SOA ns.example.org. admin.example.org. ( 1 3h 1h 1w 1d )
            example.org. IN NS ns.example.org.

            ns.example.org. IN A    192.168.0.1
            ns.example.org. IN AAAA abcd::1
          '';
        }
        {
          name = "example.com";
          master = true;
          useStructuredFormat = true;
          origin = "example.com.";
          ttl = 3600;
          soa = commonSoa;
          records = [
            {
              name = "@";
              type = "NS";
              target = "ns1.example.com.";
            }
            {
              name = "@";
              type = "A";
              address = "192.168.0.2";
            }
            {
              name = "@";
              type = "AAAA";
              address = "abcd::2";
            }
            {
              name = "ns1";
              type = "A";
              address = "192.168.0.3";
            }
            {
              name = "mail";
              type = "A";
              address = "192.168.0.4";
            }
            {
              name = "@";
              type = "MX";
              priority = 10;
              target = "mail.example.com.";
            }
            {
              name = "@";
              type = "TXT";
              text = "v=spf1 mx -all";
            }
            {
              name = "alias";
              type = "CNAME";
              target = "example.com.";
            }
          ];
        }
        {
          name = "1.0.168.192.in-addr.arpa";
          master = true;
          useStructuredFormat = true;
          origin = "1.0.168.192.in-addr.arpa.";
          ttl = 3600;
          soa = commonSoa;
          records = [
            {
              name = "@";
              type = "NS";
              target = "ns.example.org.";
            }
            {
              name = "@";
              type = "PTR";
              target = "ns.example.org.";
            }
          ];
        }
      ];
    };

  testScript = ''
    machine.wait_for_unit("bind.service")

    # Test example.org zone (traditional format)
    machine.succeed("dig @127.0.0.1 ns.example.org +short | grep -qF '192.168.0.1'")

    # Test example.com zone (structured format)
    machine.succeed("dig @127.0.0.1 example.com +short | grep -qF '192.168.0.2'")
    machine.succeed("dig @127.0.0.1 AAAA example.com +short | grep -qF 'abcd::2'")
    machine.succeed("dig @127.0.0.1 NS example.com +short | grep -qF 'ns1.example.com.'")
    machine.succeed("dig @127.0.0.1 MX example.com +short | grep -qF '10 mail.example.com.'")
    machine.succeed("dig @127.0.0.1 TXT example.com +short | grep -qF 'v=spf1 mx -all'")
    machine.succeed("dig @127.0.0.1 alias.example.com +short | grep -qF '192.168.0.2'")
    machine.succeed("dig @127.0.0.1 SOA example.com +short | grep -qF 'ns1.example.com. admin.example.com.'")

    # Test reverse DNS zone (structured format)
    machine.succeed("dig @127.0.0.1 -x 192.168.0.1 +short | grep -qF 'ns.example.org.'")
    machine.succeed("dig @127.0.0.1 SOA 1.0.168.192.in-addr.arpa +short | grep -qF 'ns1.1.0.168.192.in-addr.arpa. admin.1.0.168.192.in-addr.arpa.'")
  '';
}
