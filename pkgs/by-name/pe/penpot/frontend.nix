# The Penpot frontend: a ClojureScript (shadow-cljs) single page
# application plus statically compiled assets (sass, translations, svg
# sprites) and the WebAssembly render engine.
#
# The output of this derivation is the document root to be served by a
# web server; runtime configuration is read from js/config.js which
# deployments (e.g. the NixOS module) may replace.
{
  lib,
  stdenv,
  # passed from ./package.nix
  src,
  version,
  clojure,
  mkClojureDeps,
  penpot-render-wasm,
  fetchPnpmDeps,
  pnpm,
  pnpmConfigHook,
  nodejs,
  gitMinimal,
  rsync,
  autoPatchelfHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "penpot-frontend";
  inherit src version;

  postPatch = ''
    # deps.edn uses floating "RELEASE" versions for some dev-only
    # dependencies; pin them so dependency resolution is reproducible.
    substituteInPlace frontend/deps.edn \
      --replace-fail 'binaryage/devtools {:mvn/version "RELEASE"}' 'binaryage/devtools {:mvn/version "1.0.7"}' \
      --replace-fail 'com.bhauman/rebel-readline {:mvn/version "RELEASE"}' 'com.bhauman/rebel-readline {:mvn/version "0.1.5"}' \
      --replace-fail 'org.clojure/tools.namespace {:mvn/version "RELEASE"}' 'org.clojure/tools.namespace {:mvn/version "1.5.1"}'

    # Replace :git/tag + abbreviated :git/sha coordinates with full
    # :git/sha ones so they can be resolved offline from the gitlibs
    # checkout captured in clojureDeps (see ./package.nix).
    sed -i 's|{:git/tag "[^"]*"$|{|' frontend/deps.edn common/deps.edn
    substituteInPlace frontend/deps.edn \
      --replace-fail ':git/sha "2d9a986"' ':git/sha "2d9a986b7f3df27882e2306851df7cd2932ac310"' \
      --replace-fail ':git/sha "0f7e15a"' ':git/sha "0f7e15a26f202ac554fc436669147c1c5f311ff7"' \
      --replace-fail ':git/sha "8744c66"' ':git/sha "8744c664a96f5edddda7420deea46228ccf1f78c"' \
      --replace-fail ':git/sha "27e5a1a"' ':git/sha "27e5a1a13207363a549aacf323f7fe10b0079ae0"'
    substituteInPlace common/deps.edn \
      --replace-fail ':git/sha "3372f3a"' ':git/sha "3372f3ab33034030a6118de74592b9fb22d8c7d0"'

    # The postinstall script builds plugins-runtime with a network-enabled
    # pnpm; it is built explicitly in buildPhase instead.
    substituteInPlace frontend/package.json \
      --replace-fail '"postinstall": "(cd ../plugins/libs/plugins-runtime; pnpm install; pnpm run build)"' \
                     '"postinstall": "true"'
  '';

  clojureDeps = mkClojureDeps {
    inherit (finalAttrs)
      pname
      version
      src
      postPatch
      ;
    projectDir = "frontend";
    prepareCommands = "clojure -P -M:dev:shadow-cljs";
    hash = "sha256-//8yhX94jM7OfjkJdECmhR1HglnHZcNB6Iu/r+3Ccr0=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    sourceRoot = "${finalAttrs.src.name}/frontend";
    fetcherVersion = 4;
    hash = "sha256-/2VKrkoBfNSQWh9MzN9zY8mZvKIIEtnuSyYxCOsWk94=";
  };

  # dependencies of the plugins runtime library, which lives in a separate
  # pnpm workspace and is linked into the frontend as @penpot/plugins-runtime
  pluginsDeps = fetchPnpmDeps {
    pname = "${finalAttrs.pname}-plugins";
    inherit (finalAttrs) version src;
    sourceRoot = "${finalAttrs.src.name}/plugins";
    pnpmWorkspaces = [ "@penpot/plugins-runtime..." ];
    fetcherVersion = 4;
    hash = "sha256-+wdYUdfTopbuQzcuM1iS2VhnQnNxJmIIk7H5c0SmMjY=";
  };

  pnpmRoot = "frontend";

  nativeBuildInputs = [
    clojure
    gitMinimal
    nodejs
    rsync
    pnpm
    pnpmConfigHook
    autoPatchelfHook
  ];

  buildInputs = [
    (lib.getLib stdenv.cc.cc) # libstdc++ for prebuilt node binaries
  ];

  env = {
    NODE_ENV = "production";
    VERSION = version;
    VERSION_TAG = version; # used for cache busting; upstream appends a timestamp
  };

  buildPhase = ''
    runHook preBuild

    # Install the dependencies of the plugins workspace (filtered to
    # plugins-runtime) by re-running the pnpm config hook against it.
    pnpmRoot="plugins" pnpmDeps="$pluginsDeps" pnpmWorkspaces="@penpot/plugins-runtime..." pnpmConfigHook

    # Prebuilt binaries in node_modules (esbuild, sass-embedded, ...)
    # cannot run unpatched in the build sandbox.
    autoPatchelf frontend/node_modules plugins/node_modules

    # Build the plugins runtime, linked into the frontend as
    # @penpot/plugins-runtime (see frontend/package.json postinstall)
    pnpm --dir plugins --filter @penpot/plugins-runtime run build

    cd frontend

    # The clojure CLI expects the dependencies in $HOME. potok2's own
    # deps.edn references beicon2 by :git/tag, which cannot be resolved
    # offline; rewrite it to the full-sha coordinate of the (identical)
    # direct beicon2 dependency in a writable copy of the deps home.
    cljHome="$TMPDIR/clojure-home"
    cp -r --no-preserve=mode ${finalAttrs.clojureDeps} "$cljHome"
    sed -i 's|{:git/tag "[^"]*"$|{|' "$cljHome"/.gitlibs/libs/funcool/potok2/*/deps.edn
    substituteInPlace "$cljHome"/.gitlibs/libs/funcool/potok2/*/deps.edn \
      --replace-fail ':git/sha "e7135e0"' ':git/sha "8744c664a96f5edddda7420deea46228ccf1f78c"'

    # Upstream treats resources/public as a build directory
    rm -rf resources/public
    mkdir -p resources/public/js/worker

    # Inject the prebuilt render engine (see scripts/build)
    cp ${penpot-render-wasm}/js/render-wasm.js resources/public/js/
    cp ${penpot-render-wasm}/js/render-wasm.wasm resources/public/js/
    cp ${penpot-render-wasm}/js/worker/render.js resources/public/js/worker/
    cp ${penpot-render-wasm}/shared.js src/app/render_wasm/api/shared.js

    # Compile the application
    HOME="$cljHome" \
      JAVA_TOOL_OPTIONS="-Duser.home=$cljHome" \
      clojure -M:dev:shadow-cljs release main worker

    # Bundle vendored libraries and compile static assets
    node ./scripts/build-libs.js
    node ./scripts/build-app-assets.js

    sed -i "s/\.\/render.js/.\/render.js?version=$VERSION_TAG/g" resources/public/js/worker/main*.js

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r resources/public/. $out/

    # Default (empty) runtime configuration; deployments are expected to
    # serve their own js/config.js to configure the frontend.
    cp ../docker/images/files/config.js $out/js/config.js

    runHook postInstall
  '';

  # static web root: nothing to patch or strip
  dontFixup = true;

  meta = {
    description = "Frontend for Penpot, the open-source design tool";
    homepage = "https://github.com/penpot/penpot";
    license = lib.licenses.mpl20;
    platforms = lib.platforms.linux;
  };
})
