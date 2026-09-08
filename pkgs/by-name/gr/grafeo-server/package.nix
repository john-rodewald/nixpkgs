{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
  rustPlatform,
  fetchurl,
  pkg-config,
  openssl,
  onnxruntime,
  protobuf,
  makeWrapper,
  nix-update-script,
  nixosTests,
  tier ? "full",
}:

let
  tiers = {
    full = {
      noDefaultFeatures = false;
      features = [ "full" ];
      studio = true;
      embed = true;
    };
    standard = {
      noDefaultFeatures = false;
      features = [ ];
      studio = true;
      embed = false;
    };
    gwp = {
      noDefaultFeatures = true;
      features = [ "gwp" ];
      studio = false;
      embed = false;
    };
    bolt = {
      noDefaultFeatures = true;
      features = [ "bolt" ];
      studio = false;
      embed = false;
    };
  };

  selected = tiers.${tier} or (throw "grafeo-server: unknown tier '${tier}'");

  swaggerUi = fetchurl {
    url = "https://github.com/swagger-api/swagger-ui/archive/refs/tags/v5.17.14.zip";
    hash = "sha256-SBJE0IEgl7Efuu73n3HZQrFxYX+cn5UU5jrL4T5xzNw=";
  };

  version = "0.5.40";

  src = fetchFromGitHub {
    owner = "GrafeoDB";
    repo = "grafeo-server";
    tag = "v${version}";
    hash = "sha256-OpyHFKwlxd+xnYS4iOREdEvx1cHcq0pmipoNEQFODPE=";
  };

  studio = buildNpmPackage {
    pname = "grafeo-server-studio";
    inherit version;

    src = "${src}/client";
    npmDepsHash = "sha256-L/WyGqMxePuPE5JCBfxkqZOi+/xkOVA1S3ntTxSX/gM=";

    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
in

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "grafeo-server";
  inherit version src;

  cargoHash = "sha256-aIzYLJBfNIpwmJvo+vpaWEKPxJKbEv3L5jJVDtWUV+A=";

  buildNoDefaultFeatures = selected.noDefaultFeatures;
  buildFeatures = selected.features;

  nativeBuildInputs = [
    pkg-config
    protobuf
  ]
  ++ lib.optionals selected.embed [ makeWrapper ];

  buildInputs = [
    openssl
  ]
  ++ lib.optionals selected.embed [ onnxruntime ];

  postPatch = lib.optionalString selected.studio ''
    mkdir -p client/dist
    cp -r ${studio}/. client/dist/
  '';

  env = {
    OPENSSL_NO_VENDOR = true;
    SWAGGER_UI_DOWNLOAD_URL = "file://${swaggerUi}";
  }
  // lib.optionalAttrs selected.embed {
    ORT_STRATEGY = "system";
    ORT_LIB_LOCATION = "${onnxruntime}/lib";
  };

  doCheck = false;

  postInstall = lib.optionalString selected.embed ''
    wrapProgram $out/bin/grafeo-server \
      --set-default ORT_DYLIB_PATH "${onnxruntime}/lib/libonnxruntime.so"
  '';

  passthru = {
    inherit studio;
    tests = { inherit (nixosTests) grafeo-server; };
    updateScript = nix-update-script { };
  };

  meta = {
    description = "HTTP server for the Grafeo graph database (${tier} tier)";
    homepage = "https://github.com/GrafeoDB/grafeo-server";
    changelog = "https://github.com/GrafeoDB/grafeo-server/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "grafeo-server";
    platforms = lib.platforms.linux;
  };
})
