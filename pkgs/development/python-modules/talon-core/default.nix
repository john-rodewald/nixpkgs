{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  cssselect,
  html5lib,
  joblib,
  lxml,
  regex,
  six,
}:

buildPythonPackage {
  pname = "talon-core";
  version = "1.6.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "zulip";
    repo = "talon";
    rev = "e87a64dccc3c5ee1b8ea157d4b6e15ecd46f2bed";
    hash = "sha256-bdWn8wX0PIc2NGJpJ+GRJyOFdVxIQHrwVKq5cKIfKhM=";
  };

  sourceRoot = "source/talon-core";

  build-system = [ setuptools ];

  dependencies = [
    cssselect
    html5lib
    joblib
    lxml
    regex
    six
  ];

  pythonImportsCheck = [ "talon_core" ];

  meta = {
    description = "Mailgun library to extract message quotations and signatures (core part, maintained by the Zulip project)";
    homepage = "https://github.com/zulip/talon";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ john-rodewald ];
  };
}
