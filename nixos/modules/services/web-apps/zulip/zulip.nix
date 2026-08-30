{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.zulip;

  polkitAllowedUnits = [
    "zulip.service"
    "go-camo.service"
  ]
  ++ builtins.map (v: "${v}.service") (
    builtins.filter (lib.hasPrefix "zulip-") (builtins.attrNames config.systemd.services)
  );

  inherit (lib)
    mkEnableOption
    mkOption
    mkPackageOption
    types
    ;

  zulipUnitPath = [
    pkgs.gzip
    pkgs.bash
    pkgs.gnutar
    pkgs.nodejs
    config.services.postgresql.package
    config.systemd.package
  ];

  jsonFormat = pkgs.formats.json { };

  # Renders an attribute set as a Python settings module. Values wrapped in
  # `{ _get_secret = "key"; }` are read at runtime through
  # `zproject.config.get_secret_json`.
  pythonFormat = {
    type =
      let
        valueType =
          with types;
          nullOr (oneOf [
            bool
            float
            int
            path
            str
            (attrsOf valueType)
            (listOf valueType)
          ])
          // {
            description = "Python value";
          };
      in
      types.attrsOf valueType;
    generate =
      name: value:
      pkgs.runCommand name
        {
          nativeBuildInputs = [ pkgs.python3 ];
          value = builtins.toJSON value;
          pythonGen = ''
            import json
            import os

            print("from .config import get_secret_json")

            with open(os.environ["valuePath"], "r") as f:
                for key, value in json.load(f).items():
                    if isinstance(value, dict) and "_get_secret" in value:
                        print(f"{key} = get_secret_json({repr(value["_get_secret"])})")
                    else:
                        print(f"{key} = {repr(value)}")
          '';
          passAsFile = [
            "value"
            "pythonGen"
          ];
          preferLocalBuild = true;
        }
        ''
          python3 "$pythonGenPath" > $out
        '';
  };

  nsenterScript = pkgs.writeShellApplication {
    name = "zulip-nsenter";

    runtimeInputs = [
      pkgs.util-linux
      config.systemd.package
    ];
    text = ''
      MainPID=$(systemctl show -p MainPID --value zulip-tornado.service)

      nsenter -e -a -t "$MainPID" -G follow -S follow -w${cfg.package} "$@"
    '';
  };

  manageScript = pkgs.writeShellApplication {
    name = "zulip-manage";

    runtimeInputs = [
      pkgs.util-linux
      config.systemd.package
    ];
    text = ''
      MainPID=$(systemctl show -p MainPID --value zulip-tornado.service)

      nsenter -e -a -t "$MainPID" -G follow -S follow -w${cfg.package} ${cfg.package}/manage.py "$@"
    '';
  };

  restoreScript = pkgs.writeShellApplication {
    name = "zulip-restore";

    runtimeInputs = [
      pkgs.util-linux
      config.systemd.package
    ];
    text = ''
      MainPID=$(systemctl show -p MainPID --value zulip-tornado.service)

      nsenter -e -m -t "$MainPID" -w${cfg.package} ${cfg.package}/scripts/setup/restore-backup "$@"
    '';
  };

  queues = [
    "deferred_work"
    "digest_emails"
    "email_mirror"
    "embed_links"
    "embedded_bots"
    "email_senders"
    "deferred_email_senders"
    "missedmessage_emails"
    "missedmessage_mobile_notifications"
    "outgoing_webhooks"
    "thumbnail"
    "user_activity"
    "user_activity_interval"
  ];

  mkManageTimer =
    name: value:
    lib.nameValuePair "zulip-cron-${name}" {
      inherit (value) startAt;
      serviceConfig = zulipSystemdOneshot // {
        ExecStart = "${cfg.package}/manage.py ${value.command or (lib.replaceString "-" "_" name)}";
      };
    };

  # See puppet/zulip/manifests/app_frontend_base.pp
  cronJobs = {
    update-analytics-counts = {
      startAt = "*:05:00";
    };
    promote-new-full-members = {
      startAt = "*:35:00";
    };
    send_zulip_update_announcements = {
      # Yes this is a cron job AND a post-deploy thing
      startAt = "*:47:00";
    };
    soft-deactivate-users = {
      startAt = "05:00:00";
      command = "soft_deactivate_users -d";
    };
    delete-old-unclaimed-attachments = {
      startAt = "05:00:00";
      command = "delete_old_unclaimed_attachments -f";
    };
    archive-messages = {
      startAt = "05:00:00";
    };
    send-digest-emails = {
      startAt = "18:00:00";
      command = "enqueue_digest_emails";
    };
    update_subscriber_counts = {
      startAt = "06:00:00";
    };
    clearsessions = {
      startAt = "22:22:00";
    };
    update-channel-recently-active-status = {
      startAt = "Mon 05:00:00";
    };
  };

  LoadCredential = [
    "secret_key:${cfg.secretKeyFile}"
    "camo_key:${cfg.camoKeyFile}"
    "shared_secret:${cfg.sharedSecretKeyFile}"
    "avatar_salt:${cfg.avatarSaltKeyFile}"
    "rabbitmq_password:${cfg.rabbitmqPasswordFile}"
  ]
  ++ lib.optional (cfg.orgKeyFile != null) "zulip_org_key:${cfg.orgKeyFile}"
  ++ lib.optional (cfg.orgIdFile != null) "zulip_org_id:${cfg.orgIdFile}"
  ++ lib.mapAttrsToList (key: path: "${key}:${path}") cfg.extraSecrets;

  zulipSystemdCommon = {
    User = "zulip";
    Group = "zulip";

    Slice = "system-zulip.slice";

    WorkingDirectory = cfg.package;
    LogsDirectory = "zulip";
    X-Restart-Triggers = [ config.environment.etc."zulip/settings.py".source ];
    inherit LoadCredential;
  };

  zulipSystemdLongLived = zulipSystemdCommon // {
    Type = "exec";

    Restart = "always";
    RestartSec = "30s";
  };

  zulipSystemdOneshot = zulipSystemdCommon // {
    Type = "oneshot";
  };

  zulipInit = pkgs.writeShellApplication {
    name = "zulip-init";
    runtimeInputs = [ ];
    text = ''
      ./manage.py check
      ./manage.py migrate --noinput
      ./manage.py createcachetable third_party_api_results
    '';
  };

in
{
  options.services.zulip = {
    enable = mkEnableOption "Zulip messaging server";
    package = mkPackageOption pkgs "zulip" { };
    manageScript = mkOption {
      type = types.package;
      default = manageScript;
      defaultText = lib.literalMD "a script wrapping `manage.py` of the Zulip instance";
      description = "Script to manage the Zulip instance";
    };
    restoreScript = mkOption {
      type = types.package;
      default = restoreScript;
      defaultText = lib.literalMD "a script wrapping `scripts/setup/restore-backup` of the Zulip instance";
      description = "Script to restore Zulip backups";
    };
    nsenterScript = mkOption {
      type = types.package;
      default = nsenterScript;
      defaultText = lib.literalMD "a script entering the namespace of the Zulip services";
      description = "Script to run commands in the Zulip namespace";
    };

    uwsgiProcesses = mkOption {
      type = types.ints.positive;
      default = 4;
      description = "Number of uwsgi workers";
    };
    uwsgiPackage = mkOption {
      type = types.package;
      default = pkgs.uwsgi.override {
        plugins = [ "python3" ];
        python3 = cfg.package.pythonEnv;
      };
      defaultText = lib.literalExpression ''
        pkgs.uwsgi.override {
          plugins = [ "python3" ];
          python3 = config.services.zulip.package.pythonEnv;
        }
      '';
      description = "Uwsgi package to use";
    };
    host = mkOption {
      type = types.str;
      description = "Zulip domain";
    };
    djangoSocket = mkOption {
      type = types.path;
      default = "/run/zulip/uwsgi";
      description = "Socket that will serve the app through uwsgi protocol.";
    };
    tusdPort = mkOption {
      type = types.port;
      default = 9900;
      description = "Port used by tusd";
    };
    katexPort = mkOption {
      type = types.port;
      default = 9700;
      description = "Port used by katex";
    };
    camoPort = mkOption {
      type = types.port;
      default = 9292;
      description = "Port used by camo";
    };
    tornadoPort = mkOption {
      type = types.port;
      default = 9800;
      description = "Port used by tornado";
    };
    uwsgiConfig = mkOption {
      inherit (jsonFormat) type;
      internal = true;
      visible = false;
    };
    enablePostgresqlLocally = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to use the PostgreSQL setup provided by this NixOS module";
    };
    zulipSettings = mkOption {
      type = types.submodule {
        freeformType = pythonFormat.type;
        options = {
          LOCAL_UPLOADS_DIR = mkOption {
            type = types.str;
            default = "/var/lib/zulip/uploads";
            description = "Local folder where to put uploads";
          };
          CAMO_URI = mkOption {
            type = types.str;
            default = "/external_content/";
            internal = true;
            visible = false;
          };
          RABBITMQ_USERNAME = mkOption {
            type = types.str;
            default = "zulip";
            internal = true;
            visible = false;
          };
          RABBITMQ_VHOST = mkOption {
            type = types.str;
            default = "/";
            internal = true;
            visible = false;
          };
          AUTHENTICATION_BACKENDS = mkOption {
            type = types.listOf types.str;
            default = [ "zproject.backends.EmailAuthBackend" ];
            description = ''
              Enable at least one of the following authentication backends.
              See <https://zulip.readthedocs.io/en/latest/production/authentication-methods.html>
              for documentation on the available authentication backends.

              Do not forget to put a `lib.mkForce` if you want to enable the default authentication backend.
            '';
          };
          ZULIP_ADMINISTRATOR = mkOption {
            type = types.str;
            description = "Zulip administrator email";
          };
          EXTERNAL_HOST = mkOption {
            type = types.str;
            description = "The user-accessible Zulip hostname for this installation.";
          };
          TORNADO_QUEUE_FILENAME_PATTERN = mkOption {
            type = types.str;
            description = ''Filename pattern where to store tornado state. Must contain a "%s" placeholder.'';
            default = "/var/lib/zulip/tornado_event_queues%s.json";
          };
          LOCKFILE_DIRECTORY = mkOption {
            type = types.str;
            description = "Directory where to put zulip lockfiles";
            default = "/var/lib/zulip/zulip-locks";
          };
          TORNADO_PORTS = mkOption {
            type = types.listOf types.port;
            description = "Port used by tornado";
            default = [ cfg.tornadoPort ];
            defaultText = lib.literalExpression "[ config.services.zulip.tornadoPort ]";
          };
        };
      };
      description = ''
        Zulip settings. See
        <https://github.com/zulip/zulip/blob/main/zproject/prod_settings_template.py>
        for a list of possible values.

        Secrets can be provided using the `_get_secret` magic key. It can only be used at top level in the following manner:
        ```
        SOCIAL_AUTH_OIDC_ENABLED_IDPS = {
          _get_secret = "/etc/pathtomysecret.json";
        };
        ```
        where `/etc/pathtomysecret.json` is a json file containing the value for that setting.
      '';
    };
    camoKeyFile = mkOption {
      type = types.path;
      description = "Camo key file";
    };
    sharedSecretKeyFile = mkOption {
      type = types.path;
      description = "Shared secret for interprocess communication";
    };
    secretKeyFile = mkOption {
      type = types.path;
      description = "Django secret key for zulip";
    };
    avatarSaltKeyFile = mkOption {
      type = types.path;
      description = "Salt for non-discoverability of avatars";
    };
    rabbitmqPasswordFile = mkOption {
      type = types.path;
      description = "RabbitMQ password file. RabbitMQ will be configured with it";
    };
    orgKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Organisation key file (for zulip registration)";
    };
    orgIdFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Organisation id file (for zulip registration)";
    };
    extraSecrets = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = ''
        Extra secrets to pass to zulip. These secrets will be passed to the
        python processes through systemd credentials. One can access them
        using the `get_secret` function from the `zproject.config` module.
      '';
    };
    accessLogRetentionDays = mkOption {
      type = types.ints.positive;
      description = "Number of days of access logs to keep for the zulip application.";
      default = 14;
    };
  };
  config = lib.mkIf cfg.enable {
    services.zulip = {
      uwsgiConfig = {
        uwsgi = {
          # templates/uwsgi.ini.template.erb
          strict = true;
          chdir = "/";
          hook-post-fork = "chdir:${cfg.package}";
          lazy-apps = true;
          module = "zproject.wsgi:application";
          master = true;
          chmod-socket = 770;
          chown-socket = "zulip:zulip";
          socket = cfg.djangoSocket;
          listen = 128;
          master-fifo = "/run/zulip/control";
          enable-threads = true;
          processes = cfg.uwsgiProcesses;
          auto-procname = true;
          procname-prefix-spaced = "zulip-django";
          harakiri = 55;
          buffer-size = 65535;
          post-buffering = 4096;
          stats = "/run/zulip/uwsgi-stats";
          ignore-sigpipe = true;
          ignore-write-errors = true;
          disable-write-exception = true;

          pyhome = "${cfg.package.pythonEnv}";
          env = [
            "LANG=C.UTF-8"
            "PATH=${cfg.package.pythonEnv}/bin:${pkgs.nodejs}/bin"
          ];
        };
      };
    };

    environment.etc = {
      "zulip/settings.py".source = pythonFormat.generate "settings.py" cfg.zulipSettings;
    };

    systemd.targets = {
      zulip = {
        description = "Common target for all Zulip services.";
        wantedBy = [ "multi-user.target" ];
      };
      zulip-workers = {
        description = "Target for all zulip queues";
        wantedBy = [ "zulip.target" ];
      };
    };

    systemd.services =
      (lib.genAttrs' queues (
        queue:
        lib.nameValuePair "zulip-${queue}" {
          wantedBy = [
            "zulip.target"
            "zulip-workers.target"
          ];
          partOf = [
            "zulip.target"
            "zulip-workers.target"
          ];
          after = [
            "zulip.service"
          ];
          wants = [
            "zulip.service"
          ];
          serviceConfig = zulipSystemdLongLived // {
            ExecStart = "${cfg.package}/manage.py process_queue --queue_name=${queue} --skip-checks";
            # TODO: Hardening
          };

          path = zulipUnitPath;
        }
      ))
      // {
        zulip = {
          wantedBy = [ "zulip.target" ];
          partOf = [ "zulip.target" ];

          # Other services have already ordering and dependency statements in their setup unit
          after = [
            "redis-zulip.service"
            "memcached.service"
          ];
          requires = [
            "redis-zulip.service"
            "memcached.service"
          ];

          preStart = ''
            mkdir -p ${cfg.zulipSettings.LOCAL_UPLOADS_DIR}
          '';

          postStart = ''
            ${cfg.package}/manage.py send_zulip_update_announcements --automated --progress
          '';
          serviceConfig = zulipSystemdLongLived // {
            Type = "notify";

            ExecStartPre = lib.getExe zulipInit;
            ExecStart = "${lib.getExe cfg.uwsgiPackage} --plugin python3 --json ${jsonFormat.generate "zulip-uwsgi.json" cfg.uwsgiConfig}";
            ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
            ExecStop = "${pkgs.coreutils}/bin/kill -INT $MAINPID";
            NotifyAccess = "main";
            KillSignal = "SIGQUIT";

            RuntimeDirectory = "zulip";
            StateDirectory = "zulip";

            # TODO: Hardening
          };

          path = zulipUnitPath;
        };
        zulip-deliver_scheduled_emails = {
          wantedBy = [ "zulip.target" ];
          partOf = [ "zulip.target" ];
          after = [
            "zulip.service"
          ];
          wants = [
            "zulip.service"
          ];
          serviceConfig = zulipSystemdLongLived // {
            ExecStart = "${cfg.package}/manage.py deliver_scheduled_emails --skip-checks";

            # TODO: Hardening
          };

          path = zulipUnitPath;
        };
        zulip-deliver_scheduled_messages = {
          wantedBy = [ "zulip.target" ];
          partOf = [ "zulip.target" ];
          after = [ "zulip.service" ];
          wants = [
            "zulip.service"
          ];
          serviceConfig = zulipSystemdLongLived // {
            ExecStart = "${cfg.package}/manage.py deliver_scheduled_messages --skip-checks";

            # TODO: Hardening
          };

          path = zulipUnitPath;
        };

        zulip-tusd = {
          wantedBy = [ "zulip.target" ];
          partOf = [ "zulip.target" ];
          after = [ "zulip.service" ];
          wants = [
            "zulip.service"
          ];
          path = zulipUnitPath ++ [ pkgs.tusd ];
          serviceConfig = zulipSystemdLongLived // {
            ExecStart = "${cfg.package}/manage.py runtusd 127.0.0.1:${toString cfg.tusdPort}";

            # TODO: Hardening
          };
        };

        zulip-tornado = {
          wantedBy = [ "zulip.target" ];
          partOf = [ "zulip.target" ];
          after = [ "zulip.service" ];
          wants = [
            "zulip.service"
          ];
          serviceConfig = zulipSystemdLongLived // {
            ExecStart = "${cfg.package}/manage.py runtornado 127.0.0.1:${toString cfg.tornadoPort} --skip-checks";

            # TODO: Hardening
          };

          environment = {
            PYTHONUNBUFFERED = "1";
          };

          path = zulipUnitPath;
        };

        zulip-katex = {
          wantedBy = [ "zulip.target" ];
          partOf = [ "zulip.target" ];
          wants = [
            "zulip.service"
          ];
          path = [ pkgs.nodejs ];
          environment = {
            NODE_ENV = "production";
          };
          script = ''
            export SHARED_SECRET=$(cat $CREDENTIALS_DIRECTORY/shared_secret)
            node ${cfg.package.static}/webpack-bundles/katex_server.js ${toString cfg.katexPort}
          '';
          serviceConfig = zulipSystemdLongLived // {
            LoadCredential = [ "shared_secret:${cfg.sharedSecretKeyFile}" ];
            WorkingDirectory = cfg.package.static;
            # TODO: Hardening
          };
        };
        zulip-process-fts-updates = {
          wantedBy = [ "zulip.target" ];
          partOf = [ "zulip.target" ];
          after = [ "zulip.service" ];
          wants = [
            "zulip.service"
          ];
          path = [ cfg.package.pythonEnv ];
          serviceConfig = zulipSystemdLongLived // {
            ExecStart = "${cfg.package}/puppet/zulip/files/postgresql/process_fts_updates";
            # TODO: Hardening
          };
        };
      }
      // (lib.mapAttrs' mkManageTimer cronJobs);

    systemd.tmpfiles.settings."50-zulip"."/var/lib/zulip/source"."L+".argument = toString cfg.package;

    security.polkit = {
      enable = true;
      extraConfig = ''
        /* Allow zulip to restart itself */
        polkit.addRule(function(action, subject) {
            if (action.id == "org.freedesktop.systemd1.manage-units" && subject.user == "zulip") {
                polkit.log("action=" + action);
                polkit.log("subject=" + subject);
                  var unitSet = [${
                    lib.concatStringsSep ", " (builtins.map (v: ''"${v}"'') polkitAllowedUnits)
                  }];
                for (var i = 0; i < unitSet.length; i++) {
                    if (unitSet[i] == action.lookup("unit")) {
                        var verb = action.lookup("verb");
                        polkit.log("verb=" + verb);
                        if (verb == "start" || verb == "stop" || verb == "restart") {
                            polkit.log("Zulip authorized");
                            return polkit.Result.YES;
                        }
                    }
                }
            }
        });
      '';
    };

    users.users.zulip = {
      isSystemUser = true;
      group = "zulip";
      description = "Zulip messaging service user";
    };
    users.groups.zulip.members = [ "nginx" ];
    environment.systemPackages = [
      cfg.manageScript
      cfg.restoreScript
      cfg.nsenterScript
    ];
  };
}
