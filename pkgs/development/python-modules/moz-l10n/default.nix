{
  lib,
  buildPythonPackage,
  fetchPypi,

  # build-system
  uv-build,

  # dependencies
  click,
  fluent-syntax,
  gitignorant,
  iniparse,
  polib,

  # optional-dependencies
  lxml,
}:

buildPythonPackage rec {
  pname = "moz-l10n";
  version = "0.14.1";
  pyproject = true;

  src = fetchPypi {
    pname = "moz_l10n";
    inherit version;
    hash = "sha256-IVwvuA1ZESXRTcFQZfuGGvOUH7JMWIINANcXKH5y0jo=";
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail '"uv_build>=0.11.32,<0.12"' '"uv_build"'
  '';

  build-system = [ uv-build ];

  pythonRelaxDeps = [ "gitignorant" ];

  dependencies = [
    click
    fluent-syntax
    gitignorant
    iniparse
    polib
  ];

  optional-dependencies = {
    xml = [ lxml ];
  };

  # No tests in the sdist
  doCheck = false;

  pythonImportsCheck = [ "moz.l10n" ];

  meta = {
    description = "Mozilla tools and libraries for localization files";
    homepage = "https://github.com/mozilla/moz-l10n";
    changelog = "https://github.com/mozilla/moz-l10n/blob/v${version}/python/CHANGELOG.md";
    license = lib.licenses.asl20;
    maintainers = [ ];
  };
}
