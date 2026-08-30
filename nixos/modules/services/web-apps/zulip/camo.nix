{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.zulip;
in
{
  config = lib.mkIf cfg.enable {
    services.go-camo = {
      enable = true;
      keyFile = cfg.camoKeyFile;
      listen = "127.0.0.1:${toString cfg.camoPort}";
      # templates/supervisor/go-camo.conf.erb
      extraOptions = [
        ''-H "Strict-Transport-Security: max-age=15768000"''
        ''-H "X-Frame-Options: DENY"''
        "--metrics"
        "--verbose"
        "--allow-content-video"
        ''--user-agent="${cfg.package.name} (${cfg.host}) ${pkgs.go-camo.name}"''
      ];
    };
  };
}
