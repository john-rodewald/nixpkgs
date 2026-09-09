{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.excalidraw;
in
{
  options.services.excalidraw = {
    enable = lib.mkEnableOption "Excalidraw, a virtual whiteboard for sketching hand-drawn like diagrams";

    package = lib.mkPackageOption pkgs "excalidraw" { };

    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default =
        if cfg.settings == { } then cfg.package else cfg.package.override { inherit (cfg) settings; };
      defaultText = lib.literalExpression ''
        if config.services.excalidraw.settings == { } then
          config.services.excalidraw.package
        else
          config.services.excalidraw.package.override { inherit (config.services.excalidraw) settings; }
      '';
      description = ''
        The final package with {option}`services.excalidraw.settings` applied.
        This is the directory of static files that is served by the web server;
        use it to serve Excalidraw with a web server not supported by this module.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''
        {
          VITE_APP_WS_SERVER_URL = "https://collab.example.com";
          VITE_APP_BACKEND_V2_GET_URL = "https://json.example.com/api/v2/";
          VITE_APP_BACKEND_V2_POST_URL = "https://json.example.com/api/v2/post/";
        }
      '';
      description = ''
        Build-time configuration of Excalidraw as `VITE_APP_*` environment
        variables. Excalidraw has no runtime configuration, so setting any value
        here rebuilds {option}`services.excalidraw.package` from source.

        The available variables and their defaults, which point at the servers
        of the public instance at <https://excalidraw.com> (collaboration,
        shareable links, libraries, AI features), are listed in
        [`.env.production`](https://github.com/excalidraw/excalidraw/blob/master/.env.production)
        in the upstream repository.
      '';
    };

    domain = lib.mkOption {
      type = lib.types.str;
      example = "draw.example.com";
      description = "Domain to use for the virtual host.";
    };

    nginx = {
      enable = lib.mkEnableOption "a virtual host to serve Excalidraw through nginx";

      virtualHost = lib.mkOption {
        type = lib.types.submodule (import ../web-servers/nginx/vhost-options.nix { inherit config lib; });
        default = { };
        example = lib.literalExpression ''
          {
            enableACME = true;
            forceSSL = true;
          }
        '';
        description = "Extra configuration for the nginx virtual host of Excalidraw.";
      };
    };

    caddy = {
      enable = lib.mkEnableOption "a virtual host to serve Excalidraw through Caddy";

      virtualHost = lib.mkOption {
        type = lib.types.submodule (
          import ../web-servers/caddy/vhost-options.nix { cfg = config.services.caddy; }
        );
        default = { };
        example = lib.literalExpression ''
          {
            serverAliases = [ "draw.''${config.networking.domain}" ];
          }
        '';
        description = "Extra configuration for the Caddy virtual host of Excalidraw.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx = lib.mkIf cfg.nginx.enable {
      enable = lib.mkDefault true;
      virtualHosts.${cfg.domain} = lib.mkMerge [
        cfg.nginx.virtualHost
        {
          root = lib.mkForce cfg.finalPackage;
          locations = {
            "/".tryFiles = "$uri $uri/ /index.html";
            # File names under /assets/ contain a content hash.
            "/assets/".extraConfig = ''
              expires 1y;
            '';
          };
        }
      ];
    };

    services.caddy = lib.mkIf cfg.caddy.enable {
      enable = lib.mkDefault true;
      virtualHosts.${cfg.domain} = lib.mkMerge [
        cfg.caddy.virtualHost
        {
          hostName = lib.mkForce cfg.domain;
          extraConfig = ''
            root * ${cfg.finalPackage}
            encode
            # File names under /assets/ contain a content hash.
            @assets path /assets/*
            header @assets Cache-Control "public, max-age=31536000, immutable"
            try_files {path} /index.html
            file_server
          '';
        }
      ];
    };
  };

  meta.maintainers = with lib.maintainers; [ john-rodewald ];
}
