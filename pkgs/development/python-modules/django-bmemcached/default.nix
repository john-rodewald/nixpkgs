{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  django,
  python-binary-memcached,
}:

buildPythonPackage rec {
  pname = "django-bmemcached";
  version = "0.3.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-Tkt9lyFtuuMxwd4Q5pnKIoBLlOw6kNJ2LdXRRuaYaoo=";
  };

  build-system = [ setuptools ];

  dependencies = [
    django
    python-binary-memcached
  ];

  pythonImportsCheck = [ "django_bmemcached" ];

  meta = {
    description = "Django cache backend for memcached binary protocol with authentication, based on python-binary-memcached";
    homepage = "https://github.com/jaysonsantos/django-bmemcached";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ john-rodewald ];
  };
}
