{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  poetry-core,
  typing-inspect,
}:

buildPythonPackage rec {
  pname = "xsentinels";
  version = "1.3.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "xyngular";
    repo = "py-xsentinels";
    tag = "v${version}";
    hash = "sha256-zMCeb/+7TUCJAU/0bgx0Rg1PfdjtRZq2TjJWS3LzDh0=";
  };

  build-system = [ poetry-core ];

  dependencies = [ typing-inspect ];

  pythonImportsCheck = [ "xsentinels" ];

  meta = {
    description = "Sentinels for defaults, null and for creating sentinels/singletons";
    homepage = "https://github.com/xyngular/py-xsentinels";
    license = lib.licenses.unlicense;
    maintainers = with lib.maintainers; [ john-rodewald ];
  };
}
