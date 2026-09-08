{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.grafeo-server;

  toEnvName = key: "GRAFEO_" + lib.toUpper (builtins.replaceStrings [ "-" ] [ "_" ] key);

  toEnvValue =
    value:
    if lib.isBool value then
      lib.boolToString value
    else if lib.isList value then
      lib.concatStringsSep "," (map toString value)
    else
      toString value;

  environment = lib.mapAttrs' (
    key: value: lib.nameValuePair (toEnvName key) (toEnvValue value)
  ) cfg.settings;

  baseUrl = "http://${cfg.settings.host}:${toString cfg.settings.port}";

  provisionScript = pkgs.writeShellScript "grafeo-server-ensure-databases" ''
    set -euo pipefail
    auth=()
    if [ -n "''${GRAFEO_AUTH_TOKEN:-}" ]; then
      auth=(-H "Authorization: Bearer $GRAFEO_AUTH_TOKEN")
    fi
    until ${lib.getExe pkgs.curl} -sf "''${auth[@]}" "${baseUrl}/health" >/dev/null; do
      sleep 1
    done
    ${lib.concatMapStringsSep "\n" (name: ''
      ${lib.getExe pkgs.curl} -sf "''${auth[@]}" -X POST "${baseUrl}/db" \
        -H "Content-Type: application/json" \
        -d ${lib.escapeShellArg (builtins.toJSON { inherit name; })} \
        -o /dev/null -w "%{http_code}" | grep -qE '^(200|409)$'
    '') cfg.ensureDatabases}
  '';
in
{
  options.services.grafeo-server = {
    enable = lib.mkEnableOption "Grafeo graph database server";

    package = lib.mkPackageOption pkgs "grafeo-server" { };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the configured HTTP, GWP and Bolt ports in the firewall.";
    };

    ensureDatabases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "analytics"
        "knowledge"
      ];
      description = ''
        Databases to create on startup if they do not already exist.
        Provisioned through the HTTP API once the server is healthy.
      '';
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        Files passed to the service as EnvironmentFile, for secrets such as
        `GRAFEO_AUTH_TOKEN` or `GRAFEO_AUTH_PASSWORD`.
      '';
    };

    settings = lib.mkOption {
      description = ''
        Configuration passed to grafeo-server as `GRAFEO_*` environment variables.
        See <https://github.com/GrafeoDB/grafeo-server#configuration>.
      '';
      default = { };
      type = lib.types.submodule {
        freeformType =
          with lib.types;
          attrsOf (oneOf [
            str
            int
            bool
            (listOf str)
          ]);

        options = {
          host = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = "Bind address.";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 7474;
            description = "HTTP bind port.";
          };

          data-dir = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/grafeo-server";
            description = "Persistence directory.";
          };

          log-format = lib.mkOption {
            type = lib.types.enum [
              "pretty"
              "json"
            ];
            default = "json";
            description = "Log output format.";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.grafeo-server = {
      description = "Grafeo graph database server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      inherit environment;

      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        ExecStartPost = lib.mkIf (cfg.ensureDatabases != [ ]) provisionScript;
        EnvironmentFile = cfg.environmentFiles;
        DynamicUser = true;
        StateDirectory = "grafeo-server";
        Restart = "on-failure";
        RestartSec = 5;

        AmbientCapabilities = "";
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      cfg.settings.port
      (cfg.settings.gwp-port or 7688)
      (cfg.settings.bolt-port or 7687)
    ];
  };

  meta.maintainers = with lib.maintainers; [ ];
}
