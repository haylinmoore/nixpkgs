{
  config,
  lib,
  pkgs,
  ...
}:
let

  cfg = config.services.bind;

  bindPkg = config.services.bind.package;

  bindUser = "named";

  bindZoneCoerce =
    list:
    builtins.listToAttrs (
      lib.forEach list (zone: {
        name = zone.name;
        value = zone;
      })
    );

  bindZoneOptions =
    { name, config, ... }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Name of the zone.";
        };
        master = lib.mkOption {
          description = "Master=false means slave server";
          type = lib.types.bool;
        };
        file = lib.mkOption {
          type = lib.types.either lib.types.str lib.types.path;
          description = "Zone file resource records contain columns of data, separated by whitespace, that define the record.";
        };
        masters = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "List of servers for inclusion in stub and secondary zones.";
        };
        slaves = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "Addresses who may request zone transfers.";
          default = [ ];
        };
        allowQuery = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = ''
            List of address ranges allowed to query this zone. Instead of the address(es), this may instead
            contain the single string "any".
          '';
          default = [ "any" ];
        };
        extraConfig = lib.mkOption {
          type = lib.types.lines;
          description = "Extra zone config to be appended at the end of the zone section.";
          default = "";
        };

        useStructuredFormat = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to use the structured format for zone data instead of a raw zone file.";
        };
        origin = lib.mkOption {
          type = lib.types.str;
          default = "${name}.";
          description = "The origin domain for this zone (typically ends with a dot).";
        };
        ttl = lib.mkOption {
          type = lib.types.int;
          default = 3600;
          description = "Default TTL for records in this zone.";
        };
        soa = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                nameServer = lib.mkOption {
                  type = lib.types.str;
                  description = "Primary name server for this zone.";
                };
                adminEmail = lib.mkOption {
                  type = lib.types.str;
                  description = "Email address of the administrator (with @ replaced by .).";
                  default = "hostmaster";
                };
                serial = lib.mkOption {
                  type = lib.types.int;
                  description = "Serial number for this zone.";
                  default = 1;
                };
                refresh = lib.mkOption {
                  type = lib.types.str;
                  description = "How often secondary servers should check for updates.";
                  default = "3h";
                };
                retry = lib.mkOption {
                  type = lib.types.str;
                  description = "How long to wait before retrying failed zone transfers.";
                  default = "1h";
                };
                expire = lib.mkOption {
                  type = lib.types.str;
                  description = "How long secondary servers should consider data valid if primary is unreachable.";
                  default = "1w";
                };
                negativeCacheTtl = lib.mkOption {
                  type = lib.types.str;
                  description = "How long negative responses should be cached.";
                  default = "1h";
                };
              };
            }
          );
          default = null;
          description = "SOA record for this zone.";
        };
        records = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Record name (hostname or @ for zone apex).";
                };
                type = lib.mkOption {
                  type = lib.types.enum [
                    "A"
                    "AAAA"
                    "CNAME"
                    "MX"
                    "NS"
                    "PTR"
                    "SRV"
                    "TXT"
                  ];
                  description = "DNS record type.";
                };
                # Fields for different record types
                address = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "IP address for A or AAAA records.";
                };
                target = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Target hostname for CNAME, MX, NS, or SRV records.";
                };
                priority = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = null;
                  description = "Priority for MX or SRV records.";
                };
                weight = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = null;
                  description = "Weight for SRV records.";
                };
                port = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = null;
                  description = "Port for SRV records.";
                };
                text = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Text content for TXT records.";
                };
              };
            }
          );
          default = [ ];
          description = "List of DNS records for this zone.";
        };
      };

      # Add a config check to ensure either file or structured format is used
      config = {
        file = lib.mkIf config.useStructuredFormat (
          let
            formatSOA = soa: ''
              @ IN SOA ${soa.nameServer} ${soa.adminEmail} (
                         ${toString soa.serial}    ; Serial
                         ${soa.refresh}   ; Refresh
                         ${soa.retry}   ; Retry
                         ${soa.expire}   ; Expire
                         ${soa.negativeCacheTtl})  ; Negative Cache TTL
            '';

            formatRecord =
              record:
              if record.type == "A" then
                "${record.name} IN A ${record.address}"
              else if record.type == "AAAA" then
                "${record.name} IN AAAA ${record.address}"
              else if record.type == "CNAME" then
                "${record.name} IN CNAME ${record.target}"
              else if record.type == "MX" then
                "${record.name} IN MX ${toString record.priority} ${record.target}"
              else if record.type == "NS" then
                "${record.name} IN NS ${record.target}"
              else if record.type == "PTR" then
                "${record.name} IN PTR ${record.target}"
              else if record.type == "SRV" then
                "${record.name} IN SRV ${toString record.priority} ${toString record.weight} ${toString record.port} ${record.target}"
              else if record.type == "TXT" then
                "${record.name} IN TXT \"${record.text}\""
              else
                throw "Unsupported record type: ${record.type}";

            zoneText = ''
              $ORIGIN ${config.origin}
              $TTL ${toString config.ttl}

              ; SOA Record
              ${formatSOA config.soa}

              ; Other Records
              ${lib.concatMapStrings (r: "${formatRecord r}\n") config.records}
            '';
          in
          pkgs.writeText "zone-${config.name}" zoneText
        );
      };
    };

  confFile = pkgs.writeText "named.conf" ''
    include "/etc/bind/rndc.key";
    controls {
      inet 127.0.0.1 allow {localhost;} keys {"rndc-key";};
    };

    acl cachenetworks { ${lib.concatMapStrings (entry: " ${entry}; ") cfg.cacheNetworks} };
    acl badnetworks { ${lib.concatMapStrings (entry: " ${entry}; ") cfg.blockedNetworks} };

    options {
      listen-on { ${lib.concatMapStrings (entry: " ${entry}; ") cfg.listenOn} };
      listen-on-v6 { ${lib.concatMapStrings (entry: " ${entry}; ") cfg.listenOnIpv6} };
      allow-query-cache { cachenetworks; };
      blackhole { badnetworks; };
      forward ${cfg.forward};
      forwarders { ${lib.concatMapStrings (entry: " ${entry}; ") cfg.forwarders} };
      directory "${cfg.directory}";
      pid-file "/run/named/named.pid";
      ${cfg.extraOptions}
    };

    ${cfg.extraConfig}

    ${lib.concatMapStrings (
      zone:
      let
        zoneConfig = {
          inherit (zone) name file master;
          slaves = zone.slaves or [ ];
          masters = zone.masters or [ ];
          allowQuery = zone.allowQuery or [ "any" ];
          extraConfig = zone.extraConfig or "";
        };
      in
      ''
        zone "${zoneConfig.name}" {
          type ${if zoneConfig.master then "master" else "slave"};
          file "${zoneConfig.file}";
          ${
            if zoneConfig.master then
              ''
                allow-transfer {
                  ${lib.concatMapStrings (ip: "${ip};\n") zoneConfig.slaves}
                };
              ''
            else
              ''
                masters {
                  ${lib.concatMapStrings (ip: "${ip};\n") zoneConfig.masters}
                };
              ''
          }
          allow-query { ${lib.concatMapStrings (ip: "${ip}; ") zoneConfig.allowQuery}};
          ${zoneConfig.extraConfig}
        };
      ''
    ) (lib.attrValues cfg.zones)}
  '';

in

{

  ###### interface

  options = {

    services.bind = {

      enable = lib.mkEnableOption "BIND domain name server";

      package = lib.mkPackageOption pkgs "bind" { };

      cacheNetworks = lib.mkOption {
        default = [
          "127.0.0.0/24"
          "::1/128"
        ];
        type = lib.types.listOf lib.types.str;
        description = ''
          What networks are allowed to use us as a resolver.  Note
          that this is for recursive queries -- all networks are
          allowed to query zones configured with the `zones` option
          by default (although this may be overridden within each
          zone's configuration, via the `allowQuery` option).
          It is recommended that you limit cacheNetworks to avoid your
          server being used for DNS amplification attacks.
        '';
      };

      blockedNetworks = lib.mkOption {
        default = [ ];
        type = lib.types.listOf lib.types.str;
        description = ''
          What networks are just blocked.
        '';
      };

      ipv4Only = lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = ''
          Only use ipv4, even if the host supports ipv6.
        '';
      };

      forwarders = lib.mkOption {
        default = config.networking.nameservers;
        defaultText = lib.literalExpression "config.networking.nameservers";
        type = lib.types.listOf lib.types.str;
        description = ''
          List of servers we should forward requests to.
        '';
      };

      forward = lib.mkOption {
        default = "first";
        type = lib.types.enum [
          "first"
          "only"
        ];
        description = ''
          Whether to forward 'first' (try forwarding but lookup directly if forwarding fails) or 'only'.
        '';
      };

      listenOn = lib.mkOption {
        default = [ "any" ];
        type = lib.types.listOf lib.types.str;
        description = ''
          Interfaces to listen on.
        '';
      };

      listenOnIpv6 = lib.mkOption {
        default = [ "any" ];
        type = lib.types.listOf lib.types.str;
        description = ''
          Ipv6 interfaces to listen on.
        '';
      };

      directory = lib.mkOption {
        type = lib.types.str;
        default = "/run/named";
        description = "Working directory of BIND.";
      };

      zones = lib.mkOption {
        default = [ ];
        type =
          with lib.types;
          coercedTo (listOf attrs) bindZoneCoerce (attrsOf (lib.types.submodule bindZoneOptions));
        description = ''
          List of zones we claim authority over.
        '';
        example = {
          "example.com" = {
            master = false;
            file = "/var/dns/example.com";
            masters = [ "192.168.0.1" ];
            slaves = [ ];
            extraConfig = "";
          };
        };
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Extra lines to be added verbatim to the generated named configuration file.
        '';
      };

      extraOptions = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Extra lines to be added verbatim to the options section of the
          generated named configuration file.
        '';
      };

      configFile = lib.mkOption {
        type = lib.types.path;
        default = confFile;
        defaultText = lib.literalExpression "confFile";
        description = ''
          Overridable config file to use for named. By default, that
          generated by nixos.
        '';
      };

    };

  };

  ###### implementation

  config = lib.mkIf cfg.enable {

    networking.resolvconf.useLocalResolver = lib.mkDefault true;

    users.users.${bindUser} = {
      group = bindUser;
      description = "BIND daemon user";
      isSystemUser = true;
    };
    users.groups.${bindUser} = { };

    systemd.tmpfiles.settings."bind" = lib.mkIf (cfg.directory != "/run/named") {
      ${cfg.directory} = {
        d = {
          user = bindUser;
          group = bindUser;
          age = "-";
        };
      };
    };
    systemd.services.bind = {
      description = "BIND Domain Name Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        if ! [ -f "/etc/bind/rndc.key" ]; then
          ${bindPkg.out}/sbin/rndc-confgen -c /etc/bind/rndc.key -a -A hmac-sha256 2>/dev/null
        fi
      '';

      serviceConfig = {
        Type = "forking"; # Set type to forking, see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=900788
        ExecStart = "${bindPkg.out}/sbin/named ${lib.optionalString cfg.ipv4Only "-4"} -c ${cfg.configFile}";
        ExecReload = "${bindPkg.out}/sbin/rndc -k '/etc/bind/rndc.key' reload";
        ExecStop = "${bindPkg.out}/sbin/rndc -k '/etc/bind/rndc.key' stop";
        User = bindUser;
        RuntimeDirectory = "named";
        RuntimeDirectoryPreserve = "yes";
        ConfigurationDirectory = "bind";
        ReadWritePaths = [
          (lib.mapAttrsToList (
            name: config: if (lib.hasPrefix "/" config.file) then ("-${dirOf config.file}") else ""
          ) cfg.zones)
          cfg.directory
        ];
        CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        # Security
        NoNewPrivileges = true;
        # Sandboxing
        ProtectSystem = "strict";
        ReadOnlyPaths = "/sys";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        PrivateMounts = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RemoveIPC = true;
        RestrictAddressFamilies = [ "AF_UNIX AF_INET AF_INET6 AF_NETLINK" ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        # System Call Filtering
        SystemCallArchitectures = "native";
        SystemCallFilter = "~@mount @debug @clock @reboot @resources @privileged @obsolete acct modify_ldt add_key adjtimex clock_adjtime delete_module fanotify_init finit_module get_mempolicy init_module io_destroy io_getevents iopl ioperm io_setup io_submit io_cancel kcmp kexec_load keyctl lookup_dcookie migrate_pages move_pages open_by_handle_at perf_event_open process_vm_readv process_vm_writev ptrace remap_file_pages request_key set_mempolicy swapoff swapon uselib vmsplice";
      };

      unitConfig.Documentation = "man:named(8)";
    };
  };
}
