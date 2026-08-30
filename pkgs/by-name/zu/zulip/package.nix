{
  lib,
  stdenv,
  fetchFromGitHub,

  corepack,
  fetchPnpmDeps,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  python3,
  rsync,
  vips,

  nixosTests,
}:

let
  pythonEnv = python3.withPackages (import ./python-deps.nix);
in

stdenv.mkDerivation (finalAttrs: {
  pname = "zulip";
  version = "12.2";

  src = fetchFromGitHub {
    owner = "zulip";
    repo = "zulip";
    tag = finalAttrs.version;
    hash = "sha256-MDu2ptPb9szQiEksql5gDhXSx7eBMycEMJrlTZe2GDA=";
  };

  outputs = [
    "out"
    "emoji"
    "static"
  ];

  patches = [
    ./patches/0001-computed-settings-Use-the-static-assets-in-the-relea.patch
    ./patches/0002-computed-settings-Make-persistent-queue-filename-tun.patch
    ./patches/0003-computed-settings-Make-lockfile-directory-tunable.patch
    ./patches/0004-nginx-simplify-config-for-the-no-reverse-proxy-case.patch
    ./patches/0005-upgrade-time-Provide-the-right-upgrade-time.patch
    ./patches/0006-caching-Use-build-timestamp-to-generate-the-cache-ke.patch
    ./patches/0007-credentials-Use-loadcredentials.patch
    ./patches/0008-management-Patch-registration-script.patch
    ./patches/0009-fix-backups-Use-pg_dump-from-path.patch
    ./patches/0010-yeet-backend-large-langle-mangle-support.patch
    ./patches/0011-scripts-adapt-restart-and-reload-scripts-to-nixos.patch
    ./patches/0012-backups-fix-restore-script.patch
    ./patches/0013-config-get-rid-of-zulip.conf.patch
    ./patches/0014-frontend-fix-corepack-invocations.patch
    ./patches/0015-proxy-set-defaults-to-no-proxy.patch
    ./patches/0016-Revert-home-Add-llms.txt-endpoint-for-LLM-web-public.patch
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 3;
    pnpm = pnpm_10;
    hash = "sha256-WalUQP0heEIR9rXnL6c5v5mVhMlpT9nnzFlWpqUdI6o=";
  };

  nativeBuildInputs = [
    # WARNING: `corepack` has to be listed after `pnpmConfigHook`, otherwise the
    # derivation will not build.

    pnpm_10
    nodejs
    pnpmConfigHook
    corepack

    pythonEnv
    rsync
    vips
  ];

  buildInputs = [
    pythonEnv
  ];

  postPatch = ''
    cat << EOF > scripts/lib/setup_path.py
    def setup_path() -> None:
        pass
    EOF

    cat << EOF > tools/lib/sanity_check.py
    def check_venv(filename: str) -> None:
        pass
    EOF

    substituteInPlace scripts/lib/node_cache.py \
      --replace-quiet /usr/local/bin/corepack corepack

    substituteInPlace tools/setup/emoji/build_emoji \
      --replace-quiet '"/srv/zulip-emoji-cache"' "\"$emoji\""

    substituteInPlace zerver/management/commands/compilemessages.py \
      --replace-quiet '["git", "ls-files", "locale"]' '["find", "locale", "-type", "f"]'

    chmod +x tools/setup/emoji/build_emoji
  '';

  env = {
    avatar_salt = "not_used_here";
    initial_password_salt = "not_used_here";
    local_database_password = "";
    rabbitmq_password = "not_used_here";
    secret_key = "not_used_here";
    shared_secret = "not_used_here";

    # This time must be timezone aware; it is the release date of the
    # packaged version.
    build_timestamp = "2026-08-10T00:00:00Z";

    prefix = "zulip-server-${finalAttrs.version}";

    # We build zulip in dev mode to have all required django settings set
    DEVELOPMENT = "1";
  };

  # NOTE: The build mechanism is copied from $src/tools/build-release-tarball
  #       this allows having a package that is very close to what zulip officially supports
  buildPhase = ''
    runHook preBuild

    mkdir -p $emoji

    OUTPUT_DIR=$(mktemp -d)
    export TARBALL=$OUTPUT_DIR/$prefix.tar
    BASEDIR=$(pwd)

    # Emulate git archive, without having access to .git
    rsync -rv --filter='dir-merge,-n /.gitignore' . "$OUTPUT_DIR/$prefix/"

    cd "$OUTPUT_DIR"
    while read -r i; do
      rm -r --interactive=never "''${OUTPUT_DIR:?}/$prefix/$i"
    done <"$OUTPUT_DIR/$prefix/tools/release-tarball-exclude.txt"

    tar -cf "$TARBALL" "$prefix"
    rm -rf "$prefix"

    if tar -tf "$TARBALL" | grep -q -e ^zerver/tests; then
        set +x
        echo "BUG: Excluded files remain in tarball!"
        exit 1
    fi

    cd "$BASEDIR"

    patchShebangs tools scripts manage.py

    # Copy all the files to generate the static files
    rsync -ar --exclude="$TARBALL" . "$OUTPUT_DIR/$prefix/"

    # Add the version information file
    echo "$version-nixos" > "$OUTPUT_DIR/$prefix/zulip-git-version"

    # Add the release timestamp
    echo "$build_timestamp" > "$OUTPUT_DIR/$prefix/build_timestamp"

    cd "$OUTPUT_DIR/$prefix"

    mkdir -p "var/log"

    # Some settings need to be updated for update-prod-static to work
    cat >>zproject/prod_settings_template.py <<EOF
    DEBUG = False
    EOF

    ./tools/update-prod-static

    # We don't need duplicate copies of emoji with hashed paths, and they would break Markdown
    find prod-static/serve/generated/emoji/images/emoji/ -regex '.*\.[0-9a-f]+\.png' -delete

    echo "nixos-build" >build_id
    echo "$version-nixos" >version

    cd "$OUTPUT_DIR"

    tar --append -f "$TARBALL" "$prefix/build_id" "$prefix/version" "$prefix/zulip-git-version" "$prefix/locale" "$prefix/staticfiles.json" "$prefix/webpack-stats-production.json" "$prefix/starlight_help/dist" "$prefix/build_timestamp"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir $out && mkdir $out/prod-static

    tar --strip-components=1 -xf "$TARBALL" -C $out

    ln -sf /etc/zulip/settings.py $out/zproject/prod_settings.py
    ln -sf $static $out/prod-static/serve

    # Install the static files to their own output
    mv $prefix/prod-static/serve $static

    runHook postInstall
  '';

  passthru = {
    inherit pythonEnv;
    tests = {
      inherit (nixosTests)
        zulip
        zulip-backup
        zulip-restart
        zulip-tornado
        ;
    };
  };

  meta = {
    description = "Open-source team chat server that helps teams stay productive and focused";
    homepage = "https://zulip.com";
    changelog = "https://zulip.readthedocs.io/en/latest/overview/changelog.html";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ john-rodewald ];
    platforms = lib.platforms.linux;
  };
})
