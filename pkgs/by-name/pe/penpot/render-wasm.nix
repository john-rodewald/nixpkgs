# Penpot's new render engine: Rust compiled to WebAssembly via emscripten,
# statically linked against prebuilt skia binaries (provided by upstream,
# the same ones used for the official penpot builds).
#
# nixpkgs' rustc does not ship a standard library for the
# wasm32-unknown-emscripten target, so std is built from (vendored) source
# as part of the build via `cargo -Z build-std` (see also vodozemac-wasm).
{
  lib,
  stdenv,
  # passed from ./package.nix
  src,
  version,
  fetchurl,
  buildPackages,
  rustPlatform,
  cargo,
  emscripten,
  esbuild,
  symlinkJoin,
  removeReferencesTo,
}:

let
  # rustc with the rust library sources available, required by build-std
  sysroot = symlinkJoin {
    name = "rustc-sysroot-with-lib-src";
    paths = [ buildPackages.rustc.unwrapped ];
    postBuild = ''
      mkdir -p $out/lib/rustlib/src/rust
      ln -s ${rustPlatform.rustLibSrc} $out/lib/rustlib/src/rust/library
    '';
  };
  rustcWithLibSrc = buildPackages.rustc.override { inherit sysroot; };

  # Prebuilt skia + pregenerated bindings for the emscripten target,
  # published by upstream and pinned in render-wasm/_build_env.
  skiaBinaries = fetchurl {
    url = "https://github.com/penpot/skia-binaries/releases/download/0.93.1/skia-binaries-319323662b1685a112f5-wasm32-unknown-emscripten-gl-svg-textlayout-binary-cache-webp.tar.gz";
    hash = "sha256-kwqI/Cg2c0JrzDKOAnselx+JgSPjhn/y7wS40DpDTx0=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "penpot-render-wasm";
  inherit src version;

  cargoRoot = "render-wasm";

  cargoDeps = symlinkJoin {
    name = "${finalAttrs.pname}-${finalAttrs.version}-cargo-deps";
    paths = [
      (rustPlatform.fetchCargoVendor {
        inherit src;
        inherit (finalAttrs) cargoRoot;
        name = "${finalAttrs.pname}-${finalAttrs.version}-cargo-deps";
        hash = "sha256-Qxv3feKgQe/0+43rEehoRWibCJoxvOAHFDLY3Sq5jWs=";
      })
    ];
    # `-Z build-std` also needs the dependencies of the rust library itself
    postBuild = ''
      cp -rsn ${rustPlatform.rustVendorSrc}/* $out/*/
    '';
  };

  nativeBuildInputs = [
    cargo
    rustcWithLibSrc
    rustPlatform.cargoSetupHook
    emscripten
    esbuild
    removeReferencesTo
  ];

  postPatch = ''
    # The build scripts assume the emsdk layout and a pnpm-provided esbuild
    sed -i '/emsdk_env.sh/d' render-wasm/build
    sed -i \
      -e 's/corepack .*;/true;/' \
      -e 's/pnpm install;/true;/' \
      -e 's/pnpm exec esbuild/esbuild/' \
      -e 's/cargo build \$CARGO_PARAMS/cargo build -Z build-std $CARGO_PARAMS/' \
      -e 's/--no-entry /--no-entry -sDEFAULT_TO_CXX -sSUPPORT_LONGJMP=emscripten /' \
      render-wasm/_build_env

    patchShebangs render-wasm/build render-wasm/_build_env
  '';

  env = {
    # `-Z build-std` requires a nightly toolchain
    RUSTC_BOOTSTRAP = 1;
    # nixpkgs' rustc does not ship rust-lld; emcc drives the linking anyway.
    # The prebuilt skia binaries use the legacy emscripten-style exception
    # handling and longjmp, so rust must not use wasm exception handling
    # (see also -sSUPPORT_LONGJMP=emscripten in postPatch).
    RUSTFLAGS = "-C link-self-contained=no -Z emscripten-wasm-eh=false";
    # Make skia-bindings use the prebuilt binaries instead of downloading
    SKIA_BINARIES_URL = "file://${skiaBinaries}";
    VERSION = version;
    NODE_ENV = "production";
  };

  buildPhase = ''
    runHook preBuild

    # emscripten needs a writable cache
    export EM_CACHE="$TMPDIR/emscripten-cache"
    cp -r --no-preserve=mode ${emscripten}/share/emscripten/cache "$EM_CACHE"

    render-wasm/build

    runHook postBuild
  '';

  # The build script copies its artifacts into the frontend source tree
  installPhase = ''
    runHook preInstall

    install -Dm644 frontend/resources/public/js/render-wasm.js -t $out/js
    install -Dm644 frontend/resources/public/js/render-wasm.wasm -t $out/js
    install -Dm644 frontend/resources/public/js/worker/render.js -t $out/js/worker
    install -Dm644 frontend/src/app/render_wasm/api/shared.js -t $out

    runHook postInstall
  '';

  # std source paths (from build-std) end up in panic message strings
  preFixup = ''
    find $out -name "*.wasm" -exec remove-references-to -t ${sysroot} {} +
  '';

  meta = {
    description = "WebAssembly render engine for Penpot";
    homepage = "https://github.com/penpot/penpot";
    license = lib.licenses.mpl20;
    platforms = lib.platforms.linux;
  };
})
