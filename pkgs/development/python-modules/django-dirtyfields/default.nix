{
  lib,
  buildPythonPackage,
  fetchPypi,

  # build-system
  setuptools,

  # dependencies
  django,
}:

buildPythonPackage rec {
  pname = "django-dirtyfields";
  version = "1.9.9";
  pyproject = true;

  src = fetchPypi {
    pname = "django_dirtyfields";
    inherit version;
    hash = "sha256-wRyOA4JxZtLJH2Y0pNEPWqXMfqQw1g5b1Xaz6/MZFy8=";
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail '"setuptools >= 80.9.0, < 81"' '"setuptools"'
  '';

  build-system = [ setuptools ];

  dependencies = [ django ];

  # Tests require a running PostgreSQL instance
  doCheck = false;

  pythonImportsCheck = [ "dirtyfields" ];

  meta = {
    description = "Tracking dirty fields on a Django model instance";
    homepage = "https://github.com/romgar/django-dirtyfields";
    changelog = "https://github.com/romgar/django-dirtyfields/blob/${version}/ChangeLog.rst";
    license = lib.licenses.bsd3;
    maintainers = [ ];
  };
}
