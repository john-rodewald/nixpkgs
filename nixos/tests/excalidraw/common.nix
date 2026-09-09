{ lib, ... }:

{
  meta.maintainers = with lib.maintainers; [ john-rodewald ];

  nodes.machine.services.excalidraw = {
    enable = true;
    domain = lib.mkDefault "localhost";
  };

  testScript =
    { nodes, ... }:
    let
      webServer = if nodes.machine.services.nginx.enable then "nginx" else "caddy";
    in
    ''
      import re

      machine.wait_for_unit("${webServer}.service")
      machine.wait_for_open_port(80)

      def get(path):
          return machine.succeed(f"curl --fail --silent --show-error http://localhost{path}")

      def headers(path):
          return machine.succeed(f"curl --fail --silent --show-error --head http://localhost{path}").lower()

      with subtest("Index page is served"):
          index = get("/")
          assert "<title>Excalidraw" in index

      with subtest("Unknown paths fall back to the index page"):
          assert get("/some/unknown/path") == index
          assert "max-age=31536000" not in headers("/")

      with subtest("Content-hashed assets are served with a long cache lifetime"):
          assets = re.findall(r'(?:src|href)="(/assets/[^"]+)"', index)
          assert assets, "no assets referenced in index.html"
          for asset in assets:
              assert "max-age=31536000" in headers(asset), f"{asset} is not cacheable"

      with subtest("Fonts are served locally instead of from upstream's CDN"):
          assert "digitaloceanspaces" not in index
          fonts = re.findall(r'href="(/fonts/[^"]+\.woff2)"', index)
          assert fonts, "no fonts referenced in index.html"
          for font in fonts:
              assert "font/woff2" in headers(font), f"{font} is not a font"

      with subtest("Third-party scripts are not loaded"):
          assert "simpleanalytics" not in index
          assert "fonts.googleapis.com" not in index

      with subtest("PWA files are served"):
          assert "application/manifest+json" in headers("/manifest.webmanifest")
          assert "javascript" in headers("/sw.js")
    '';
}
