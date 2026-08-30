{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
}:

buildPythonPackage rec {
  pname = "loadcredential";
  version = "1.3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Tom-Hubrecht";
    repo = "loadcredential";
    tag = "v${version}";
    hash = "sha256-dv7a7XpFELIPIf2AUWMPHO3LgzsUz4vBCtFk8MeEOZQ=";
  };

  build-system = [ setuptools ];

  pythonImportsCheck = [ "loadcredential" ];

  meta = {
    description = "Simple python package to read credentials passed through systemd's LoadCredential, with a fallback on env variables";
    homepage = "https://github.com/Tom-Hubrecht/loadcredential";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ john-rodewald ];
  };
}
