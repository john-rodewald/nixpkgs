{
  lib,
  buildPythonPackage,
  fetchPypi,

  # build-system
  setuptools,

  # dependencies
  fluent-syntax,
  six,
  toml,
}:

buildPythonPackage rec {
  pname = "compare-locales";
  version = "9.0.5";
  pyproject = true;

  src = fetchPypi {
    pname = "compare_locales";
    inherit version;
    hash = "sha256-gvIXdVJmbQ968czClAqNVi80XOOi5k8bZ4U9RX6orjM=";
  };

  build-system = [ setuptools ];

  dependencies = [
    fluent-syntax
    six
    toml
  ];

  # No tests in the sdist
  doCheck = false;

  pythonImportsCheck = [
    "compare_locales"
    "compare_locales.parser"
  ];

  meta = {
    description = "Lint tool for localization files in the Mozilla project";
    homepage = "https://github.com/mozilla/compare-locales";
    changelog = "https://github.com/mozilla/compare-locales/blob/RELEASE_${version}/docs/releasenotes.rst";
    license = lib.licenses.mpl20;
    mainProgram = "compare-locales";
    maintainers = [ ];
  };
}
