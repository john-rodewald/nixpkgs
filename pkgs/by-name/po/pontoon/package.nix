{
  lib,
  python3,
  fetchFromGitHub,
  fetchNpmDeps,
  nodejs,
  npmHooks,
  nixosTests,
}:

let
  python = python3;
  python3Packages = python.pkgs;
in
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "pontoon";
  version = "2026.08.28";
  pyproject = true;

  outputs = [
    "out"
    "static"
  ];

  src = fetchFromGitHub {
    owner = "mozilla";
    repo = "pontoon";
    tag = "v${finalAttrs.version}";
    hash = "sha256-dkbD3c4CScedgdP4DJGsx4Bkx+6FfAWzZG4mFOeToL8=";
  };

  postPatch = ''
    # Upstream doesn't maintain the version in setup.py
    substituteInPlace setup.py \
      --replace-fail 'version="1.0"' 'version="${finalAttrs.version}"'
  '';

  build-system = with python3Packages; [ setuptools ];

  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) src;
    hash = "sha256-0eBz37+YU+DWEmyovhcaxnXvYlkj2+chzgNNP0X8sR0=";
  };

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
  ];

  # Upstream pins all dependencies in requirements/*.txt, but the
  # setuptools metadata declares no dependencies at all, so there is
  # nothing to relax here.
  dependencies =
    with python3Packages;
    [
      beautifulsoup4
      bleach
      celery
      compare-locales
      dj-database-url
      django
      django-ace
      django-allauth
      django-cors-headers
      django-csp
      django-dirtyfields
      django-filter
      django-guardian
      django-jinja
      django-notifications-community
      django-pipeline
      djangorestframework
      drf-spectacular
      google-cloud-translate
      gunicorn
      markupsafe
      moz-l10n
      openai
      psycopg2
      pyjwt
      python-dateutil
      python-dotenv
      rapidfuzz
      requests
      sacrebleu
      sacremoses
      translate-toolkit
      whitenoise
    ]
    ++ django-allauth.optional-dependencies.socialaccount
    ++ drf-spectacular.optional-dependencies.sidecar
    ++ moz-l10n.optional-dependencies.xml;

  # Build the translate frontend and collect all static files (processed
  # with django-pipeline, compressed and hashed by whitenoise) into a
  # separate output.
  postBuild = ''
    npm run build:prod

    export SECRET_KEY="not-a-secret-only-used-for-collectstatic"
    export DJANGO_SETTINGS_MODULE="pontoon.settings"
    export DATABASE_URL="sqlite://:memory:"
    export STATIC_ROOT="$static"
    mkdir -p $static
    ${python.pythonOnBuildForHost.interpreter} manage.py collectstatic --no-input
  '';

  postInstall = ''
    sitePackages=$out/${python.sitePackages}

    # The settings derive the repository root from the location of the
    # pontoon package. The jinja template and the static files of the
    # translate frontend are expected relative to it.
    mkdir -p $sitePackages/translate
    cp -r translate/public translate/dist $sitePackages/translate/

    # Expose the Django management script, akin to django-admin
    install -Dm755 manage.py $out/bin/pontoon-manage
    sed -i "1c#!${python.interpreter}" $out/bin/pontoon-manage
  '';

  # Tests require a running PostgreSQL instance and are run in the NixOS test
  doCheck = false;

  passthru = {
    inherit python;
    tests = {
      inherit (nixosTests) pontoon;
    };
  };

  meta = {
    description = "Mozilla's localization platform";
    homepage = "https://pontoon.mozilla.org/";
    changelog = "https://github.com/mozilla/pontoon/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
    maintainers = [ ];
    mainProgram = "pontoon-manage";
  };
})
