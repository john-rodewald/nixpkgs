{ config, lib, ... }:
let
  cfg = config.services.zulip;

  locations = import ./nginx-locations.nix {
    zulip-package = cfg.package;
    inherit (cfg.zulipSettings) LOCAL_UPLOADS_DIR;
  };
in
{
  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      upstreams = {
        # puppet/zulip/files/nginx/zulip-include-frontend/upstreams
        django.servers."unix:${cfg.djangoSocket}" = { };
        camo.servers."127.0.0.1:${toString cfg.camoPort}" = { };
        tusd.servers."127.0.0.1:${toString cfg.tusdPort}" = { };

        # puppet/zulip/templates/nginx/tornado-upstreams.conf.template.erb
        tornado = {
          servers."127.0.0.1:${toString cfg.tornadoPort}" = { };
          extraConfig = ''
            keepalive 10000;
          '';
        };
      };
      # puppet/zulip/templates/nginx/zulip-enterprise.template.erb
      virtualHosts."127.0.0.1" = {
        listen = [
          {
            addr = "127.0.0.1";
            port = 80;
          }
          {
            addr = "[::1]";
            port = 80;
          }
        ];
        inherit locations;
      };

      virtualHosts.${cfg.host} = {
        enableACME = lib.mkDefault true;
        forceSSL = lib.mkDefault true;
        extraConfig = ''
          error_page 502 503 504 /static/webpack-bundles/5xx.html;
        '';
        inherit locations;
      };
    };
  };
}
