{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  pygments,
}:

buildPythonPackage rec {
  pname = "jsx-lexer";
  version = "2.0.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "fcurella";
    repo = "jsx-lexer";
    tag = "v${version}";
    hash = "sha256-1CFhj0sEccPCDd9qqA5QgB4n1lzVnkWnr9a/EMLYQuU=";
  };

  build-system = [ setuptools ];

  dependencies = [ pygments ];

  pythonImportsCheck = [ "jsx" ];

  meta = {
    description = "JSX lexer for Pygments";
    homepage = "https://github.com/fcurella/jsx-lexer";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ john-rodewald ];
  };
}
