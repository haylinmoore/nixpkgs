{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.duckdns;
  duckdns = pkgs.writeShellScriptBin "duckdns" ''
    # duckdns_update [LABEL] QUERY [CURL_ARGS...]
    duckdns_update() {
        local prefix="''${1:+$1: }" query=$2
        shift 2
        DRESPONSE=$(curl -sS --max-time 60 --no-progress-meter "$@" -K- <<< "url = \"https://www.duckdns.org/update?verbose=true&domains=$DUCKDNS_DOMAINS&token=$DUCKDNS_TOKEN&$query\"")
        IPV4=$(echo "$DRESPONSE" | awk 'NR==2')
        IPV6=$(echo "$DRESPONSE" | awk 'NR==3')
        RESPONSE=$(echo "$DRESPONSE" | awk 'NR==1')
        IPCHANGE=$(echo "$DRESPONSE" | awk 'NR==4')

        if [[ "$RESPONSE" = "OK" ]] && [[ "$IPCHANGE" = "UPDATED" ]]; then
            if [[ "$IPV4" != "" ]] && [[ "$IPV6" == "" ]]; then
                echo "''${prefix}Your IP was updated at $(date) to IPv4: $IPV4"
            elif [[ "$IPV4" == "" ]] && [[ "$IPV6" != "" ]]; then
                echo "''${prefix}Your IP was updated at $(date) to IPv6: $IPV6"
            else
                echo "''${prefix}Your IP was updated at $(date) to IPv4: $IPV4 & IPv6 to: $IPV6"
            fi
        elif [[ "$RESPONSE" = "OK" ]] && [[ "$IPCHANGE" = "NOCHANGE" ]]; then
            echo "''${prefix}DuckDNS request at $(date) successful. IP(s) unchanged."
        else
            echo -e "''${prefix}Something went wrong, please check your settings\nThe response returned was:\n$DRESPONSE\n"
            return 1
        fi
    }

    status=0
    ${lib.optionalString cfg.ipv4.enable ''
      duckdns_update "${lib.optionalString cfg.ipv6.enable "IPv4"}" "ip=" ${lib.optionalString cfg.ipv6.enable "-4"} || status=1
    ''}
    ${lib.optionalString cfg.ipv6.enable ''
      ADDRESS=$(ip -6 -o addr show dev ${lib.escapeShellArg cfg.ipv6.interface} scope global -temporary -deprecated -tentative -dadfailed \
          | awk -v suffix=${lib.escapeShellArg (lib.toLower cfg.ipv6.addressSuffix)} '
              { split($4, a, "/"); addr = a[1] }
              addr !~ /^f[cd]/ && substr(addr, length(addr) - length(suffix) + 1) == suffix { print addr; exit }
          ')
      if [[ -n "$ADDRESS" ]]; then
          duckdns_update IPv6 "ipv6=$ADDRESS" || status=1
      else
          echo "IPv6: no suitable address found on interface ${cfg.ipv6.interface}"
          status=1
      fi
    ''}
    exit $status
  '';
in
{
  options.services.duckdns = {
    enable = lib.mkEnableOption "DuckDNS Dynamic DNS Client";
    tokenFile = lib.mkOption {
      default = null;
      type = lib.types.path;
      description = ''
        The path to a file containing the token
        used to authenticate with DuckDNS.
      '';
    };

    domains = lib.mkOption {
      default = null;
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      example = [ "examplehost" ];
      description = ''
        The domain(s) to update in DuckDNS
        (without the .duckdns.org suffix)
      '';
    };

    domainsFile = lib.mkOption {
      default = null;
      type = lib.types.nullOr lib.types.path;
      example = lib.literalExpression ''
        pkgs.writeText "duckdns-domains.txt" '''
          examplehost
          examplehost2
          examplehost3
        '''
      '';
      description = ''
        The path to a file containing a
        newline-separated list of DuckDNS
        domain(s) to be updated
        (without the .duckdns.org suffix)
      '';
    };

    ipv4.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to update the IPv4 address.
        DuckDNS detects it from the source address of the request.
      '';
    };

    ipv6 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to update the IPv6 address.
          The address is taken from {option}`services.duckdns.ipv6.interface` and sent in a separate request.
        '';
      };

      interface = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "eth0";
        description = ''
          The network interface to take the IPv6 address from.
          The first global, non-temporary, non-deprecated address that is not a unique local address (`fc00::/7`) is used.
        '';
      };

      addressSuffix = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "::243";
        description = ''
          Only use an address ending in this string, e.g. to select a static address among several on {option}`services.duckdns.ipv6.interface`.
          It is compared against the compressed form of the address as printed by `ip -6 addr`.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.domains != null || cfg.domainsFile != null;
        message = "Either services.duckdns.domains or services.duckdns.domainsFile has to be defined";
      }
      {
        assertion = !(cfg.domains != null && cfg.domainsFile != null);
        message = "services.duckdns.domains and services.duckdns.domainsFile can't both be defined at the same time";
      }
      {
        assertion = (cfg.tokenFile != null);
        message = "services.duckdns.tokenFile has to be defined";
      }
      {
        assertion = cfg.ipv4.enable || cfg.ipv6.enable;
        message = "At least one of services.duckdns.ipv4.enable and services.duckdns.ipv6.enable has to be set";
      }
      {
        assertion = cfg.ipv6.enable -> cfg.ipv6.interface != null;
        message = "services.duckdns.ipv6.interface has to be defined when services.duckdns.ipv6.enable is set";
      }
    ];

    environment.systemPackages = [ duckdns ];

    systemd.services.duckdns = {
      description = "DuckDNS Dynamic DNS Client";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      startAt = "*:0/5";
      path = [
        pkgs.gnused
        config.systemd.package
        pkgs.curl
        pkgs.gawk
        duckdns
      ]
      ++ lib.optionals cfg.ipv6.enable [ pkgs.iproute2 ];
      serviceConfig = {
        Type = "simple";
        LoadCredential = [
          "DUCKDNS_TOKEN_FILE:${cfg.tokenFile}"
        ]
        ++ lib.optionals (cfg.domainsFile != null) [ "DUCKDNS_DOMAINS_FILE:${cfg.domainsFile}" ];
        DynamicUser = true;

        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        PrivateDevices = true;
        PrivateUsers = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ]
        ++ lib.optionals cfg.ipv6.enable [ "AF_NETLINK" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
        UMask = "0077";
      };
      script = ''
        export DUCKDNS_TOKEN=$(systemd-creds cat DUCKDNS_TOKEN_FILE)
        ${lib.optionalString (cfg.domains != null) ''
          export DUCKDNS_DOMAINS='${lib.strings.concatStringsSep "," cfg.domains}'
        ''}
        ${lib.optionalString (cfg.domainsFile != null) ''
          export DUCKDNS_DOMAINS=$(systemd-creds cat DUCKDNS_DOMAINS_FILE | sed -z 's/\n/,/g')
        ''}
        exec ${lib.getExe duckdns}
      '';
    };
  };

  meta.maintainers = with lib.maintainers; [
    notthebee
    haylin
  ];
}
