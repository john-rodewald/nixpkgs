# Inspired from /puppet/zulip/templates/logrotate/zulip.template.erb
{ config, lib, ... }:
let
  cfg = config.services.zulip;
in
{
  services.logrotate = lib.mkIf cfg.enable {
    enable = true;
    settings = {
      "zulip" = {
        files = [
          "/var/log/zulip/analytics.log"
          "/var/log/zulip/auth.log"
          "/var/log/zulip/digest.log"
          "/var/log/zulip/email_deliverer.log"
          "/var/log/zulip/email_content.log"
          "/var/log/zulip/email_mirror.log"
          "/var/log/zulip/errors.log"
          "/var/log/zulip/ldap.log"
          "/var/log/zulip/manage.log"
          "/var/log/zulip/message_retention.log"
          "/var/log/zulip/deliver_scheduled_messages.log"
          "/var/log/zulip/send_email.log"
          "/var/log/zulip/slow_queries.log"
          "/var/log/zulip/soft_deactivation.log"
          "/var/log/zulip/sync_ldap_user_data.log"
          "/var/log/zulip/webhooks_errors.log"
          "/var/log/zulip/webhooks_unsupported_events.log"
          "/var/log/zulip/workers.log"
        ];
        missingok = true;
        rotate = 3;
        size = "25M";
        compress = true;
        delaycompress = true;
        notifempty = true;
        create = "644 zulip zulip";
      };
      "/var/log/zulip/server.log" = {
        missingok = true;
        rotate = cfg.accessLogRetentionDays;
        daily = true;
        compress = true;
        delaycompress = true;
        notifempty = true;
        create = "644 zulip zulip";
      };
      # Remaining logfiles are handled by systemd's journal
    };
  };
}
