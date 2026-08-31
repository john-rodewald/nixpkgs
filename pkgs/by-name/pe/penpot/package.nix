# Penpot backend: a Clojure (JVM) application built with tools.build
# into an uberjar. The frontend, exporter and render engine live in
# passthru (they are separate services / artifacts sharing this source).
{
  lib,
  stdenv,
  callPackage,
  fetchFromGitHub,
  clojure,
  jdk25,
  gitMinimal,
  makeWrapper,
  # runtime tools invoked by the backend for media/font processing
  imagemagick,
  fontforge,
  woff2,
  woff-tools,
  python3,
  nixosTests,
}:

let
  # Penpot requires a recent JDK, both at build and run time (upstream
  # builds with JDK >= 25); keep both in sync.
  jdk = jdk25;
  clojure' = clojure.override { inherit jdk; };
  mkClojureDeps = callPackage ./clojure-deps.nix { clojure = clojure'; };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "penpot";
  version = "2.17.2";

  src = fetchFromGitHub {
    owner = "penpot";
    repo = "penpot";
    tag = finalAttrs.version;
    hash = "sha256-9WZxy24W4dmniPWdTf5TFhAYqNH/YpSVEiHDCxDR6N4=";
  };

  # Replace :git/tag + abbreviated :git/sha coordinates with full
  # :git/sha ones: resolving a tag requires access to the (impure) bare
  # git repository, while a full sha can be resolved offline from the
  # gitlibs checkout captured in clojureDeps.
  postPatch = ''
    sed -i 's|{:git/tag "[^"]*"$|{|' backend/deps.edn common/deps.edn
    substituteInPlace backend/deps.edn \
      --replace-fail ':git/sha "88701f4"' ':git/sha "88701f41b126688b8d22605fa3ea924878e78934"'
    substituteInPlace common/deps.edn \
      --replace-fail ':git/sha "3372f3a"' ':git/sha "3372f3ab33034030a6118de74592b9fb22d8c7d0"'
  '';

  clojureDeps = mkClojureDeps {
    pname = "penpot-backend";
    inherit (finalAttrs) version src postPatch;
    projectDir = "backend";
    prepareCommands = ''
      clojure -P
      clojure -P -T:build jar
    '';
    hash = "sha256-UBWWRY4VU2+U6OSmKIC3HbXcLqlNDgeLyrJkNc6APhg=";
  };

  nativeBuildInputs = [
    clojure'
    gitMinimal
    makeWrapper
  ];

  # mirrors backend/scripts/build, minus the template prefetching: the
  # builtin templates are fetched lazily by the backend at runtime
  buildPhase = ''
    runHook preBuild

    export HOME=${finalAttrs.clojureDeps}
    export JAVA_TOOL_OPTIONS="-Duser.home=$HOME"

    cd backend

    mkdir -p target/classes
    echo "${finalAttrs.version}" > target/classes/version.txt
    cp ../CHANGES.md target/classes/changelog.md

    clojure -T:build jar

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/penpot/backend $out/bin
    cp target/penpot.jar $out/share/penpot/backend/
    cp resources/log4j2.xml $out/share/penpot/backend/
    cp scripts/manage.py $out/share/penpot/backend/

    # JVM flags from backend/scripts/run.template.sh
    makeWrapper ${jdk}/bin/java $out/bin/penpot-backend \
      --prefix PATH : ${
        lib.makeBinPath [
          imagemagick
          fontforge
          woff-tools
          woff2
        ]
      } \
      --add-flags "-Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager" \
      --add-flags "-Dlog4j2.configurationFile=$out/share/penpot/backend/log4j2.xml" \
      --add-flags "-XX:-OmitStackTraceInFastThrow" \
      --add-flags "--sun-misc-unsafe-memory-access=allow" \
      --add-flags "--enable-native-access=ALL-UNNAMED" \
      --add-flags "--enable-preview" \
      --add-flags "\$JVM_OPTS" \
      --add-flags "-jar $out/share/penpot/backend/penpot.jar" \
      --add-flags "-m app.main"

    # administrative CLI, talks to the prepl socket of a running backend
    makeWrapper ${lib.getExe (python3.withPackages (ps: [ ps.tabulate ]))} $out/bin/penpot-manage \
      --add-flags "$out/share/penpot/backend/manage.py"

    runHook postInstall
  '';

  passthru = {
    frontend = callPackage ./frontend.nix {
      inherit (finalAttrs) src version;
      inherit mkClojureDeps;
      inherit (finalAttrs.passthru) penpot-render-wasm;
      clojure = clojure';
    };

    exporter = callPackage ./exporter.nix {
      inherit (finalAttrs) src version;
      inherit mkClojureDeps;
      clojure = clojure';
    };

    penpot-render-wasm = callPackage ./render-wasm.nix {
      inherit (finalAttrs) src version;
    };

    tests = { inherit (nixosTests) penpot; };
  };

  meta = {
    description = "Open-source design and prototyping platform (backend)";
    homepage = "https://penpot.app";
    changelog = "https://github.com/penpot/penpot/blob/${finalAttrs.version}/CHANGES.md";
    license = lib.licenses.mpl20;
    platforms = lib.platforms.linux;
    maintainers = [ ];
    mainProgram = "penpot-backend";
  };
})
