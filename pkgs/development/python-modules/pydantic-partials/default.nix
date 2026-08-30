{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  poetry-core,
  pydantic,
  xsentinels,
}:

buildPythonPackage rec {
  pname = "pydantic-partials";
  version = "4.1.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "joshorr";
    repo = "pydantic-partials";
    tag = "v${version}";
    hash = "sha256-jJgsK9XY0+MbfvcATN4l9rSfekFqf4bS6vCIt5f7UDA=";
  };

  build-system = [ poetry-core ];

  dependencies = [
    pydantic
    xsentinels
  ];

  pythonImportsCheck = [ "pydantic_partials" ];

  meta = {
    description = "Pydantic partial model class, with ability to easily dynamically omit fields when serializing a model";
    homepage = "https://github.com/joshorr/pydantic-partials";
    license = lib.licenses.unlicense;
    maintainers = with lib.maintainers; [ john-rodewald ];
  };
}
