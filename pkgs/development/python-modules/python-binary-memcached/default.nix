{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  six,
  uhashring,
}:

buildPythonPackage rec {
  pname = "python-binary-memcached";
  version = "0.32.0";
  pyproject = true;

  src = fetchPypi {
    pname = "python_binary_memcached";
    inherit version;
    hash = "sha256-0FcuHbWmGmwxhe14O4M30A1l0esVIeIwKjbkXV4Ps7c=";
  };

  build-system = [ setuptools ];

  dependencies = [
    six
    uhashring
  ];

  pythonImportsCheck = [ "bmemcached" ];

  meta = {
    description = "Pure python module to access memcached via its binary protocol with SASL auth support";
    homepage = "https://github.com/jaysonsantos/python-binary-memcached";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ john-rodewald ];
  };
}
