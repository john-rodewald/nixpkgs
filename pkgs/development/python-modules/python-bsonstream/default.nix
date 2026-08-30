{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  pymongo,
  six,
}:

buildPythonPackage rec {
  pname = "python-bsonstream";
  version = "0.1.4";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-8TDxCFAFf9+pe0Olw/FNCdEaN2h3emfQsFdH26ppKmE=";
  };

  build-system = [ setuptools ];

  dependencies = [
    pymongo
    six
  ];

  pythonImportsCheck = [ "bsonstream" ];

  meta = {
    description = "Utility for reading streams of BSON documents";
    homepage = "https://pypi.org/project/python-bsonstream/";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ john-rodewald ];
  };
}
