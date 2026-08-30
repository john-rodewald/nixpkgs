{
  lib,
  buildPythonPackage,
  fetchPypi,

  # build-system
  setuptools,
  setuptools-scm,
}:

buildPythonPackage rec {
  pname = "django-pipeline";
  version = "4.1.0";
  pyproject = true;

  src = fetchPypi {
    pname = "django_pipeline";
    inherit version;
    hash = "sha256-qh15328hW3g5bN1Q7RYvh0HcSZPp+6LHhIPZtvHnIrQ=";
  };

  build-system = [
    setuptools
    setuptools-scm
  ];

  # Tests require a Django project setup and various JS binaries
  doCheck = false;

  pythonImportsCheck = [ "pipeline" ];

  meta = {
    description = "Asset packaging library for Django";
    homepage = "https://github.com/jazzband/django-pipeline";
    changelog = "https://github.com/jazzband/django-pipeline/blob/${version}/HISTORY.rst";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
}
