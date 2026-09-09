{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchYarnDeps,
  yarnConfigHook,
  yarnBuildHook,
  nodejs,
  nix-update-script,
  nixosTests,
  # Build-time configuration of the web app as `VITE_APP_*` environment
  # variables. Excalidraw has no runtime configuration; everything (e.g. the
  # collaboration server, the share-link backend) is baked in at build time.
  # See `.env.production` in the upstream repository for the available keys.
  settings ? { },
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "excalidraw";
  version = "0.18.1";

  src = fetchFromGitHub {
    owner = "excalidraw";
    repo = "excalidraw";
    tag = "v${finalAttrs.version}";
    hash = "sha256-XhxNXi6JwBq5vw+/6HQTp6NPX3etmCkdBdNboeBru/k=";
  };

  yarnOfflineCache = fetchYarnDeps {
    yarnLock = finalAttrs.src + "/yarn.lock";
    hash = "sha256-otUEr4bGhOGYQmfELShqc8lXbRs0gA0ycbGHzyCW8tc=";
  };

  nativeBuildInputs = [
    yarnConfigHook
    yarnBuildHook
    nodejs
  ];

  strictDeps = true;

  postPatch = ''
    # Serve fonts from the web root instead of upstream's CDN. All fonts are
    # part of the build output, and "/" is upstream's fallback location anyway.
    substituteInPlace scripts/woff2/woff2-vite-plugins.js \
      --replace-fail \
        'const OSS_FONTS_CDN = "https://excalidraw.nyc3.cdn.digitaloceanspaces.com/oss/";' \
        'const OSS_FONTS_CDN = "/";'

    # Do not load upstream's third-party analytics script and drop the stale
    # preconnect hints to Google Fonts (all fonts are self-hosted).
    sed -i \
      -e '/<!-- 100% privacy friendly analytics -->/,/<!-- end LEGACY GOOGLE ANALYTICS -->/d' \
      -e '/rel="preconnect" href="https:\/\/fonts\.g\(oogleapis\|static\)\.com"/d' \
      excalidraw-app/index.html
    if grep -E -q 'simpleanalyticscdn|fonts\.g(oogleapis|static)\.com' excalidraw-app/index.html; then
      echo "error: failed to remove third-party references from excalidraw-app/index.html" >&2
      exit 1
    fi
  '';

  # Vite gives variables from the process environment precedence over the
  # `.env.production` file, so the defaults can be overridden here.
  env = settings;

  # `engines.node` is pinned to `18.0.0 - 22.x.x` in this release (relaxed to
  # `>=18.0.0` upstream since). `yarnConfigHook` already ignores engines for
  # `yarn install`; do the same for `yarn run`, including the nested
  # `yarn --cwd ./excalidraw-app` invocation of the build script.
  preBuild = ''
    yarn config --offline set ignore-engines true
  '';

  # Same build script as upstream's Docker image; disables Sentry.
  # In-app event tracking is disabled through `.env.production`.
  yarnBuildScript = "build:app:docker";

  installPhase = ''
    runHook preInstall

    cp -r excalidraw-app/build $out

    runHook postInstall
  '';

  passthru = {
    tests = {
      inherit (nixosTests.excalidraw) caddy nginx;
    };
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Virtual whiteboard for sketching hand-drawn like diagrams";
    longDescription = ''
      Excalidraw is a virtual collaborative whiteboard tool that lets you easily
      sketch diagrams that have a hand-drawn feel to them.

      This package contains the static web app. Serve it with a web server, for
      example through the `services.excalidraw` NixOS module.
    '';
    homepage = "https://excalidraw.com";
    changelog = "https://github.com/excalidraw/excalidraw/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ john-rodewald ];
    platforms = lib.platforms.all;
  };
})
