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
  pname = "django-ace";
  version = "1.44.0";
  pyproject = true;

  src = fetchPypi {
    pname = "django_ace";
    inherit version;
    hash = "sha256-HTpTL64jOs0ob9IXh5oGWgdMpG9+g36i1zy3NrB/xys=";
  };

  build-system = [ setuptools ];

  dependencies = [ django ];

  # No tests in the sdist
  doCheck = false;

  pythonImportsCheck = [ "django_ace" ];

  meta = {
    description = "Django integration of the ACE code editor";
    homepage = "https://github.com/django-ace/django-ace";
    changelog = "https://github.com/django-ace/django-ace/releases/tag/${version}";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
}
