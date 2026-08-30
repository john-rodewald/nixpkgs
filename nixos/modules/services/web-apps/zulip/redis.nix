# From puppet/zulip/templates/zulip-redis.template.erb
{ config, lib, ... }:
let
  cfg = config.services.zulip;
in
{
  config = lib.mkIf cfg.enable {
    services.redis.servers.zulip = {
      enable = true;
      port = 6379;
      save = [ ];
    };
    users.groups."${config.services.redis.servers.zulip.user}".members = [ "zulip" ];
    systemd.services."redis-zulip" = {
      wantedBy = [ "zulip.target" ];
      partOf = [ "zulip.target" ];
      serviceConfig.Slice = "system-zulip.slice";
    };
  };
}
