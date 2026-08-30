# puppet/zulip/manifests/profile/rabbitmq.pp and puppet/zulip/files/rabbitmq/*
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.zulip;

  configureScript = pkgs.writeShellApplication {
    name = "zulip-configure-rabbitmq";
    runtimeInputs = [
      pkgs.rabbitmq-server
    ];

    text = ''
      RABBITMQ_USERNAME=${lib.escapeShellArg cfg.zulipSettings.RABBITMQ_USERNAME}
      RABBITMQ_VHOST=${lib.escapeShellArg cfg.zulipSettings.RABBITMQ_VHOST}
      RABBITMQ_PASSWORD=$(cat "$CREDENTIALS_DIRECTORY/rabbitmq_password")

      if rabbitmqctl list_users --quiet | grep -q "$RABBITMQ_USERNAME"; then
        echo 'zulip rabbitmq user already exist. We assume it is well configured. Delete the user with "cd / && sudo -u rabbitmq rabbitmqctl delete_user guest" if you want to run the configuration script anyway.'
        exit 0
      fi

      rabbitmqctl await_startup
      rabbitmqctl delete_user "$RABBITMQ_USERNAME" || true
      rabbitmqctl delete_user zulip || true
      rabbitmqctl delete_user guest || true
      rabbitmqctl add_user "$RABBITMQ_USERNAME" "$RABBITMQ_PASSWORD"
      rabbitmqctl set_user_tags "$RABBITMQ_USERNAME" administrator
      if ! rabbitmqctl list_vhosts --no-table-headers --quiet | grep -qx "$RABBITMQ_VHOST"; then
          rabbitmqctl add_vhost "$RABBITMQ_VHOST"
      fi
      rabbitmqctl set_permissions -p "$RABBITMQ_VHOST" "$RABBITMQ_USERNAME" '.*' '.*' '.*'
    '';
  };

in
{
  config = lib.mkIf cfg.enable {
    services.rabbitmq = {
      enable = true;
    };
    systemd.services.zulip-configure-rabbitmq = {
      serviceConfig = {
        Slice = "system-zulip.slice";
        Type = "oneshot";
        ExecStart = lib.getExe configureScript;
        LoadCredential = [
          "rabbitmq_password:${cfg.rabbitmqPasswordFile}"
        ];
        User = "rabbitmq";
        WorkingDirectory = "/";
      };

      after = [ "rabbitmq.service" ];
      before = [
        "zulip.service"
      ];
      wants = [ "rabbitmq.service" ];
      requiredBy = [ "zulip.service" ];
      partOf = [ "zulip.target" ];
    };
  };
}
