{
  lib,
  buildPythonPackage,
  fetchPypi,

  # build-system
  hatchling,
}:

buildPythonPackage rec {
  pname = "gitignorant";
  version = "0.4.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-zfP5HTyZkpBoyz6E1kwd8vBkcyUrXeaScxTop/z/yco=";
  };

  build-system = [ hatchling ];

  # No tests in the sdist
  doCheck = false;

  pythonImportsCheck = [ "gitignorant" ];

  meta = {
    description = "Spec-compliant gitignore parser for Python";
    homepage = "https://github.com/valohai/gitignorant";
    changelog = "https://github.com/valohai/gitignorant/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
}
