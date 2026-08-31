# Builds a fixed-output derivation containing the maven repository
# (~/.m2) and git dependencies (~/.gitlibs) of a deps.edn based project.
#
# The whole $HOME of the dependency resolution run is captured so that
# git dependencies (resolved by tools.gitlibs into ~/.gitlibs) work
# offline as well. Pattern adapted from pkgs/by-name/re/repath-studio.
#
# Note: the output hash depends on the clojure CLI version (it resolves
# its own implementation dependencies), so hashes need to be regenerated
# when the clojure package is updated.
{
  lib,
  stdenv,
  clojure,
  git,
  cacert,
}:

{
  pname,
  version,
  src,
  postPatch ? "",
  # directory inside the source tree containing deps.edn
  projectDir,
  # commands that resolve/download all required dependencies
  prepareCommands,
  hash,
}:

stdenv.mkDerivation {
  pname = "${pname}-deps";
  inherit version src postPatch;

  nativeBuildInputs = [
    clojure
    git
    cacert
  ];

  dontConfigure = true;
  dontFixup = true;

  buildPhase = ''
    runHook preBuild

    mkdir -p "$out"
    export HOME="$out"
    export JAVA_TOOL_OPTIONS="-Duser.home=$out"

    pushd ${lib.escapeShellArg projectDir}
    ${prepareCommands}
    popd

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Remove ephemeral maven metadata that is not reproducible
    find "$out/.m2/repository" -type f \
      \( -name \*.lastUpdated \
      -o -name resolver-status.properties \
      -o -name _remote.repositories \) \
      -delete

    if [ -d "$out/.gitlibs" ]; then
      # Delete .git pointers to the bare repositories in _repos
      find "$out/.gitlibs/libs" -type f -name .git -delete

      # Only the checkouts in .gitlibs/libs are needed offline; the bare
      # repositories in _repos are not reproducible, but their (empty)
      # config files must exist so the CLI does not try to re-fetch.
      find "$out/.gitlibs/_repos" -type f -name "config" -print0 | while read -r -d "" file; do
        dir="$(dirname "$file")"
        rm -rf "$dir"
        mkdir -p "$dir"
        touch "$file"
      done
    fi

    # Reset non-reproducible tool state
    rm -rf "$out/.clojure" "$out/.cache" "$out/.config" "$out/.java"
    mkdir -p "$out/.clojure/tools"
    echo "{}" > "$out/.clojure/deps.edn"
    echo "{}" > "$out/.clojure/tools/tools.edn"

    runHook postInstall
  '';

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = hash;
}
