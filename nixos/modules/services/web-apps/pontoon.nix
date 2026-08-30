{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.pontoon;

  dataDir = "/var/lib/pontoon";
  secretsDir = "/run/pontoon-secrets";
  dotenvFile = "${secretsDir}/env";

  finalPackage = cfg.package;
  inherit (finalPackage) python;

  pythonEnv = python.buildEnv.override {
    extraLibs = [ (python.pkgs.toPythonModule finalPackage) ];
  };

  # Pontoon is configured entirely through environment variables, see
  # https://mozilla-pontoon.readthedocs.io/en/latest/admin/deployment.html
  environment = {
    DJANGO_SETTINGS_MODULE = "pontoon.settings";
    # Secrets (SECRET_KEY, optionally EMAIL_HOST_PASSWORD) are loaded
    # through python-dotenv from a file generated at runtime.
    DOTENV_PATH = dotenvFile;

    SITE_URL = "https://${cfg.localDomain}";
    ALLOWED_HOSTS = cfg.localDomain;
    CSRF_TRUSTED_ORIGINS = "https://${cfg.localDomain}";

    STATIC_ROOT = "${finalPackage.static}";
    MEDIA_ROOT = "${dataDir}/media";

    CELERY_ALWAYS_EAGER = "False";
    RABBITMQ_URL = "amqp://guest:guest@localhost:5672//";
  }
  // lib.optionalAttrs cfg.configurePostgresql {
    # No host means connecting through the default UNIX socket in
    # /run/postgresql, authenticated via peer authentication.
    DATABASE_URL = "postgres:///pontoon";
    # TLS is neither possible nor needed on a UNIX socket connection.
    DATABASE_SSLMODE = "False";
  }
  // lib.optionalAttrs cfg.smtp.enable {
    EMAIL_HOST = cfg.smtp.host;
    EMAIL_PORT = toString cfg.smtp.port;
    DEFAULT_FROM_EMAIL = cfg.smtp.from;
  }
  // lib.optionalAttrs (cfg.smtp.enable && cfg.smtp.user != null) {
    EMAIL_HOST_USER = cfg.smtp.user;
  }
  // cfg.extraEnvironment;

  # A wrapper around the Django management script with the service
  # environment set, for interactive use as the pontoon user:
  #   sudo -u pontoon pontoon-manage shell
  manageScript = pkgs.writeShellScriptBin "pontoon-manage" ''
    ${lib.concatStrings (
      lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}\n") environment
    )}
    exec ${finalPackage}/bin/pontoon-manage "$@"
  '';

in
{

  options = {
    services.pontoon = {
      enable = lib.mkEnableOption "Pontoon, Mozilla's localization platform";

      package = lib.mkPackageOption pkgs "pontoon" { };

      localDomain = lib.mkOption {
        description = "The domain name serving your Pontoon instance.";
        example = "pontoon.example.org";
        type = lib.types.str;
      };

      secretKeyFile = lib.mkOption {
        description = ''
          Location of the Django secret key.

          This should be a path pointing to a file with secure permissions
          (not /nix/store). It only has to be readable by root, as it is
          copied to a location readable by the pontoon user at runtime.
        '';
        type = lib.types.path;
      };

      configurePostgresql = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable and configure a local PostgreSQL server by creating a
          user and database for Pontoon. If you disable this option you must
          provide a `DATABASE_URL` in {option}`services.pontoon.extraEnvironment`.
        '';
      };

      extraEnvironment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = {
          PROJECT_MANAGERS = "pm@example.org";
          VCS_SYNC_NAME = "Pontoon";
        };
        description = ''
          Additional environment variables used to configure Pontoon.

          See the [deployment documentation](https://mozilla-pontoon.readthedocs.io/en/latest/admin/deployment.html)
          for the available settings.
        '';
      };

      smtp = {
        enable = lib.mkEnableOption "Pontoon SMTP support";

        from = lib.mkOption {
          description = "The from address being used in sent emails.";
          example = "pontoon@example.com";
          default = config.services.pontoon.smtp.user;
          defaultText = "config.services.pontoon.smtp.user";
          type = lib.types.str;
        };

        user = lib.mkOption {
          description = "SMTP login name.";
          example = "pontoon@example.org";
          type = lib.types.nullOr lib.types.str;
          default = null;
        };

        host = lib.mkOption {
          description = "SMTP host used when sending emails to users.";
          type = lib.types.str;
          example = "127.0.0.1";
        };

        port = lib.mkOption {
          description = "SMTP port used when sending emails to users.";
          type = lib.types.port;
          default = 587;
          example = 25;
        };

        passwordFile = lib.mkOption {
          description = ''
            Location of a file containing the SMTP password.

            This should be a path pointing to a file with secure permissions
            (not /nix/store).
          '';
          type = lib.types.nullOr lib.types.path;
          default = null;
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.localDomain}" = {

        forceSSL = true;
        enableACME = true;

        locations = {
          "/static/" = {
            alias = "${finalPackage.static}/";
            # Serve the precompressed assets generated at build time.
            extraConfig = ''
              gzip_static on;
            '';
          };
          "/media/".alias = "${dataDir}/media/";
          "/" = {
            proxyPass = "http://unix:/run/pontoon.socket";
            # Pontoon relies on the X-Forwarded-Proto header for
            # SECURE_PROXY_SSL_HEADER and SECURE_SSL_REDIRECT.
            recommendedProxySettings = true;
          };
        };
      };
    };

    # Make the secrets available to the pontoon user, in the dotenv format
    # understood by Pontoon.
    systemd.services.pontoon-secrets = {
      description = "Pontoon secret setup";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "pontoon-secrets";
        RuntimeDirectoryMode = "0750";
        Group = "pontoon";
      };
      script = ''
        umask 027
        {
          printf "SECRET_KEY='%s'\n" "$(cat ${lib.escapeShellArg cfg.secretKeyFile})"
          ${lib.optionalString (cfg.smtp.enable && cfg.smtp.passwordFile != null) ''
            printf "EMAIL_HOST_PASSWORD='%s'\n" "$(cat ${lib.escapeShellArg cfg.smtp.passwordFile})"
          ''}
        } > ${dotenvFile}
        chgrp pontoon ${dotenvFile}
      '';
    };

    systemd.services.pontoon-postgresql-setup = lib.mkIf cfg.configurePostgresql {
      description = "Pontoon PostgreSQL setup";
      after = [ "postgresql.target" ];
      requires = [ "postgresql.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        Group = "postgres";
        # The fuzzystrmatch extension can only be created by a superuser
        ExecStart = ''
          ${config.services.postgresql.package}/bin/psql pontoon -c "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch"
        '';
      };
    };

    systemd.services.pontoon-migrate = {
      description = "Pontoon migration";
      after = [
        "pontoon-secrets.service"
      ]
      ++ lib.optional cfg.configurePostgresql "pontoon-postgresql-setup.service";
      requires = [
        "pontoon-secrets.service"
      ]
      ++ lib.optional cfg.configurePostgresql "pontoon-postgresql-setup.service";
      # We want this to be active on boot, not just on socket activation
      wantedBy = [ "multi-user.target" ];
      inherit environment;
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "pontoon";
        User = "pontoon";
        Group = "pontoon";
        ExecStart = "${finalPackage}/bin/pontoon-manage migrate --noinput";
      };
    };

    systemd.services.pontoon-celery = {
      description = "Pontoon Celery worker";
      after = [
        "network.target"
        "rabbitmq.service"
        "pontoon-migrate.service"
      ];
      requires = [
        "rabbitmq.service"
        "pontoon-migrate.service"
      ];
      # We want this to be active on boot, not just on socket activation
      wantedBy = [ "multi-user.target" ];
      inherit environment;
      serviceConfig = {
        ExecStart = ''
          ${pythonEnv}/bin/celery --app=pontoon.base.celeryapp worker \
            --loglevel=info \
            --without-gossip \
            --without-mingle \
            --without-heartbeat
        '';
        StateDirectory = "pontoon";
        WorkingDirectory = dataDir;
        User = "pontoon";
        Group = "pontoon";
        Restart = "always";
      };
    };

    systemd.services.pontoon = {
      description = "Pontoon Gunicorn app";
      after = [
        "network.target"
        "pontoon-migrate.service"
        "pontoon-celery.service"
      ];
      requires = [
        "pontoon-migrate.service"
        "pontoon.socket"
      ];
      wants = [ "pontoon-celery.service" ];
      inherit environment;
      preStart = ''
        mkdir -p ${dataDir}/media
      '';
      serviceConfig = {
        Type = "notify";
        NotifyAccess = "all";
        ExecStart = ''
          ${pythonEnv}/bin/gunicorn \
            --name=pontoon \
            --bind='unix:/run/pontoon.socket' \
            pontoon.wsgi:application
        '';
        ExecReload = "${lib.getExe' pkgs.coreutils "kill"} -s HUP $MAINPID";
        KillMode = "mixed";
        PrivateTmp = true;
        WorkingDirectory = dataDir;
        StateDirectory = "pontoon";
        User = "pontoon";
        Group = "pontoon";
      };
    };

    systemd.sockets.pontoon = {
      before = [ "nginx.service" ];
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = "/run/pontoon.socket";
        SocketUser = "pontoon";
        SocketGroup = "pontoon";
        SocketMode = "770";
      };
    };

    services.rabbitmq.enable = true;

    services.postgresql = lib.mkIf cfg.configurePostgresql {
      enable = true;
      ensureUsers = [
        {
          name = "pontoon";
          ensureDBOwnership = true;
        }
      ];
      ensureDatabases = [ "pontoon" ];
    };

    users.users.pontoon = {
      isSystemUser = true;
      group = "pontoon";
      packages = [ manageScript ];
    };

    users.groups.pontoon.members = [ config.services.nginx.user ];
  };

  meta.maintainers = [ ];

}
