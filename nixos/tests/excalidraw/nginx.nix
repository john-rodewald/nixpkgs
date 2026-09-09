{
  imports = [ ./common.nix ];

  name = "excalidraw-nginx";

  nodes.machine.services.excalidraw.nginx.enable = true;
}
