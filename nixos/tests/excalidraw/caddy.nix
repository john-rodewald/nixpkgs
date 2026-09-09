{
  imports = [ ./common.nix ];

  name = "excalidraw-caddy";

  nodes.machine.services.excalidraw = {
    # Serve plain HTTP; automatic HTTPS is skipped for sites on port 80.
    domain = "localhost:80";
    caddy.enable = true;
  };
}
