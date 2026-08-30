# puppet/zulip/manifests/profile/memcached.pp
{ config, lib, ... }:
let
  cfg = config.services.zulip;
in
{
  config = lib.mkIf cfg.enable {
    services.memcached = {
      enable = true;
      maxMemory = 512;
      extraOptions = [
        "-a"
        "0660"
      ];
    };
    users.groups."memcached".members = [ "zulip" ];
  };
}
