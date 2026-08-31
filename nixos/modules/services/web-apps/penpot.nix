{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.penpot;

  flags = toString cfg.flags;

  # runtime configuration for the frontend single page application
  frontendConfig = pkgs.writeText "penpot-config.js" ''
    var penpotFlags = "${flags}";
    ${cfg.frontendExtraConfig}
  '';

  # proxy_http_version is already set by proxyWebsockets for the
  # notifications endpoint
  commonProxyConfig = ''
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  '';

  proxyConfig = ''
    proxy_http_version 1.1;
  ''
  + commonProxyConfig;

  backendUri = "http://127.0.0.1:${toString cfg.backendPort}";
  exporterUri = "http://127.0.0.1:${toString cfg.exporterPort}";
  redisUri = "redis://127.0.0.1:${toString cfg.redis.port}/0";

  assetsDir = "/var/lib/penpot/assets";
in
{
  options.services.penpot = {
    enable = lib.mkEnableOption "Penpot, the open-source design and prototyping platform";

    package = lib.mkPackageOption pkgs "penpot" { };

    frontendPackage = lib.mkPackageOption pkgs [ "penpot" "frontend" ] { };

    exporterPackage = lib.mkPackageOption pkgs [ "penpot" "exporter" ] { };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      example = "design.example.org";
      description = "Domain under which Penpot is served (nginx virtual host name).";
    };

    publicUri = lib.mkOption {
      type = lib.types.str;
      default = "http://${cfg.domain}";
      defaultText = lib.literalExpression ''"http://''${config.services.penpot.domain}"'';
      example = "https://design.example.org";
      description = ''
        The URI under which Penpot is reachable by users. This must match
        exactly what is typed into the browser address bar.
      '';
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/keys/penpot-secret";
      description = ''
        Path to an environment file containing `PENPOT_SECRET_KEY`, the
        master key from which other keys are derived, e.g.

        ```
        PENPOT_SECRET_KEY=<random string>
        ```

        Generate the random string with e.g.
        `python3 -c "import secrets; print(secrets.token_urlsafe(64))"`.
      '';
    };

    flags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "enable-login-with-password"
        "enable-registration"
        "disable-email-verification"
        "enable-prepl-server"
      ]
      ++ lib.optional (lib.hasPrefix "http://" cfg.publicUri) "disable-secure-session-cookies";
      defaultText = lib.literalExpression ''
        [
          "enable-login-with-password"
          "enable-registration"
          "disable-email-verification"
          "enable-prepl-server"
        ]
        ++ lib.optional (lib.hasPrefix "http://" config.services.penpot.publicUri)
          "disable-secure-session-cookies"
      '';
      description = ''
        Feature flags for Penpot, applied to both the backend and the
        frontend. See <https://help.penpot.app/technical-guide/configuration/>.
        Email verification is disabled by default because no SMTP server is
        configured out of the box; `enable-prepl-server` (bound to
        localhost) is required by the `penpot-manage` admin tool.
      '';
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        PENPOT_SMTP_HOST = "localhost";
        PENPOT_SMTP_PORT = "25";
        PENPOT_TELEMETRY_ENABLED = "true";
      };
      description = ''
        Extra environment variables for the backend service, see
        <https://help.penpot.app/technical-guide/configuration/> for
        available options.
      '';
    };

    frontendExtraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        var penpotOIDCName = "My SSO";
      '';
      description = "Extra JavaScript appended to the frontend runtime configuration (`js/config.js`).";
    };

    backendPort = lib.mkOption {
      type = lib.types.port;
      default = 6060;
      description = "Internal port of the backend API service (bound to 127.0.0.1).";
    };

    exporter = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to run the exporter service, which is required for
          exporting designs as PNG/SVG/PDF files.
        '';
      };

      internalUri = lib.mkOption {
        type = lib.types.str;
        default = cfg.publicUri;
        defaultText = lib.literalExpression "config.services.penpot.publicUri";
        description = ''
          URI under which the exporter's headless browser reaches the
          Penpot frontend.
        '';
      };
    };

    exporterPort = lib.mkOption {
      type = lib.types.port;
      default = 6061;
      description = "Internal port of the exporter service (bound to 127.0.0.1).";
    };

    database.createLocally = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to create a local PostgreSQL database automatically. When
        disabled, configure the database connection through
        {option}`services.penpot.environment`
        (`PENPOT_DATABASE_URI`, `PENPOT_DATABASE_USERNAME`,
        `PENPOT_DATABASE_PASSWORD`).
      '';
    };

    redis = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to create a local Redis server automatically. When
          disabled, set `PENPOT_REDIS_URI` through
          {option}`services.penpot.environment`.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 6379;
        description = "Port of the local Redis server.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = lib.mkIf cfg.database.createLocally {
      enable = true;
      ensureDatabases = [ "penpot" ];
      ensureUsers = [
        {
          name = "penpot";
          ensureDBOwnership = true;
        }
      ];
      # The backend (JDBC) can only connect over TCP. Note: this trusts
      # every local process to connect as the penpot database user.
      authentication = lib.mkBefore ''
        host penpot penpot 127.0.0.1/32 trust
        host penpot penpot ::1/128 trust
      '';
    };

    services.redis.servers.penpot = lib.mkIf cfg.redis.createLocally {
      enable = true;
      inherit (cfg.redis) port;
    };

    systemd.services.penpot-backend = {
      description = "Penpot backend";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
      ]
      ++ lib.optional cfg.database.createLocally "postgresql.target"
      ++ lib.optional cfg.redis.createLocally "redis-penpot.service";
      requires =
        lib.optional cfg.database.createLocally "postgresql.target"
        ++ lib.optional cfg.redis.createLocally "redis-penpot.service";

      environment = {
        PENPOT_FLAGS = flags;
        PENPOT_PUBLIC_URI = cfg.publicUri;
        PENPOT_HTTP_SERVER_HOST = "127.0.0.1";
        PENPOT_HTTP_SERVER_PORT = toString cfg.backendPort;
        PENPOT_TELEMETRY_ENABLED = "false";
        PENPOT_OBJECTS_STORAGE_BACKEND = "fs";
        PENPOT_OBJECTS_STORAGE_FS_DIRECTORY = assetsDir;
        PENPOT_REDIS_URI = redisUri;
      }
      // lib.optionalAttrs cfg.database.createLocally {
        PENPOT_DATABASE_URI = "postgresql://127.0.0.1:${toString config.services.postgresql.settings.port}/penpot";
        PENPOT_DATABASE_USERNAME = "penpot";
        PENPOT_DATABASE_PASSWORD = "";
      }
      // cfg.environment;

      serviceConfig = {
        ExecStart = lib.getExe' cfg.package "penpot-backend";
        EnvironmentFile = [ cfg.secretKeyFile ];
        User = "penpot";
        Group = "penpot";
        StateDirectory = "penpot";
        StateDirectoryMode = "0750";
        WorkingDirectory = "/var/lib/penpot";
        Restart = "always";

        # hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        CapabilityBoundingSet = [ "" ];
        SystemCallArchitectures = "native";
      };
    };

    systemd.services.penpot-exporter = lib.mkIf cfg.exporter.enable {
      description = "Penpot exporter";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "penpot-backend.service"
      ]
      ++ lib.optional cfg.redis.createLocally "redis-penpot.service";
      requires = lib.optional cfg.redis.createLocally "redis-penpot.service";

      environment = {
        PENPOT_PUBLIC_URI = cfg.publicUri;
        PENPOT_INTERNAL_URI = cfg.exporter.internalUri;
        PENPOT_HOST = "127.0.0.1";
        PENPOT_HTTP_SERVER_PORT = toString cfg.exporterPort;
        PENPOT_REDIS_URI = redisUri;
        # writable home for the headless browser
        HOME = "/var/lib/penpot-exporter";
      };

      serviceConfig = {
        ExecStart = lib.getExe cfg.exporterPackage;
        EnvironmentFile = [ cfg.secretKeyFile ];
        User = "penpot";
        Group = "penpot";
        StateDirectory = "penpot-exporter";
        WorkingDirectory = "/var/lib/penpot-exporter";
        Restart = "always";

        # hardening; the sandboxed browser needs user namespaces
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
      };
    };

    users.users.penpot = {
      isSystemUser = true;
      group = "penpot";
    };
    users.groups.penpot = { };

    # nginx must be able to read the assets directory (X-Accel-Redirect)
    users.users.${config.services.nginx.user}.extraGroups = [ "penpot" ];

    services.nginx = {
      enable = true;
      virtualHosts.${cfg.domain} = {
        # matches the upstream limits (PENPOT_HTTP_SERVER_MAX_MULTIPART_BODY_SIZE)
        extraConfig = ''
          client_max_body_size 367001600;
        '';

        root = "${cfg.frontendPackage}";

        locations = {
          "/" = {
            tryFiles = "$uri /index.html$is_args$args /index.html =404";
            extraConfig = ''
              add_header Cache-Control "no-store, no-cache, max-age=0" always;
            '';
          };

          "~* \\.(js|css|jpg|png|svg|gif|ttf|woff|woff2|wasm|map)$".extraConfig = ''
            add_header Cache-Control "public, max-age=604800" always;
          '';

          "= /js/config.js" = {
            alias = frontendConfig;
            extraConfig = ''
              types { } default_type "application/javascript";
            '';
          };

          "/api" = {
            proxyPass = "${backendUri}/api";
            extraConfig = proxyConfig + ''
              proxy_buffering off;
            '';
          };

          "/readyz" = {
            proxyPass = "${backendUri}/readyz";
            extraConfig = proxyConfig;
          };

          "/assets" = {
            proxyPass = "${backendUri}/assets";
            extraConfig = proxyConfig;
          };

          "/internal/assets/" = {
            alias = "${assetsDir}/";
            extraConfig = "internal;";
          };

          "/ws/notifications" = {
            proxyPass = "${backendUri}/ws/notifications";
            proxyWebsockets = true;
            extraConfig = commonProxyConfig;
          };
        }
        // lib.optionalAttrs cfg.exporter.enable {
          "/api/export" = {
            proxyPass = exporterUri;
            extraConfig = proxyConfig;
          };
        };
      };
    };
  };

  meta.maintainers = [ ];
}
