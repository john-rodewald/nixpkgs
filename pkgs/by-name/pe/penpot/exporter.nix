# The exporter renders and exports Penpot documents (PNG/SVG/PDF) by
# driving a headless chromium via playwright. It is a ClojureScript
# (shadow-cljs) application running on node.
{
  lib,
  stdenv,
  # passed from ./package.nix
  src,
  version,
  clojure,
  mkClojureDeps,
  fetchPnpmDeps,
  pnpm,
  pnpmConfigHook,
  nodejs,
  makeWrapper,
  playwright-driver,
  poppler-utils,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "penpot-exporter";
  inherit src version;

  # see ./package.nix: make the datoteka git dependency resolvable offline
  postPatch = ''
    sed -i 's|{:git/tag "[^"]*"$|{|' common/deps.edn
    substituteInPlace common/deps.edn \
      --replace-fail ':git/sha "3372f3a"' ':git/sha "3372f3ab33034030a6118de74592b9fb22d8c7d0"'
  '';

  clojureDeps = mkClojureDeps {
    inherit (finalAttrs)
      pname
      version
      src
      postPatch
      ;
    projectDir = "exporter";
    prepareCommands = "clojure -P -M:dev:shadow-cljs";
    hash = "sha256-1U10CmSQpJIHQ0K39rpIUgItTBVtvVdoto4oDXecQt0=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    sourceRoot = "${finalAttrs.src.name}/exporter";
    fetcherVersion = 4;
    hash = "sha256-vDZfXXzx4SDhSBdEFq/fQ1WJ3pleFz3QQIU8cSQ53rs=";
  };

  pnpmRoot = "exporter";

  nativeBuildInputs = [
    clojure
    nodejs
    pnpm
    pnpmConfigHook
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild

    cd exporter

    # The clojure CLI expects the dependencies in $HOME
    export HOME=${finalAttrs.clojureDeps}
    export JAVA_TOOL_OPTIONS="-Duser.home=$HOME"

    clojure -M:dev:shadow-cljs release main

    sed -i -e "s/%version%/${finalAttrs.version}/g" target/app.js

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/penpot-exporter $out/bin
    cp target/app.js $out/lib/penpot-exporter/
    cp package.json $out/lib/penpot-exporter/
    # runtime dependencies; the pnpm-created node_modules is self-contained
    cp -a node_modules $out/lib/penpot-exporter/

    makeWrapper ${lib.getExe nodejs} $out/bin/penpot-exporter \
      --add-flags "$out/lib/penpot-exporter/app.js" \
      --prefix PATH : ${lib.makeBinPath [ poppler-utils ]} \
      --set-default NODE_ENV production \
      --set-default PLAYWRIGHT_BROWSERS_PATH ${playwright-driver.browsers}

    runHook postInstall
  '';

  meta = {
    description = "Exporter service for Penpot";
    homepage = "https://github.com/penpot/penpot";
    license = lib.licenses.mpl20;
    platforms = lib.platforms.linux;
    mainProgram = "penpot-exporter";
  };
})
