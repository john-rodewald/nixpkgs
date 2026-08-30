{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  django,
  six,
}:

buildPythonPackage rec {
  pname = "django-bitfield";
  version = "2.3.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "disqus";
    repo = "django-bitfield";
    tag = version;
    hash = "sha256-GzKbvTcb1+uXIwkUdMthpQQXva8P+Xr0JVnmW4tT52A=";
  };

  build-system = [ setuptools ];

  dependencies = [
    django
    six
  ];

  pythonImportsCheck = [ "bitfield" ];

  meta = {
    description = "BitField extension for Django models";
    homepage = "https://github.com/disqus/django-bitfield";
    changelog = "https://github.com/disqus/django-bitfield/releases/tag/${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ john-rodewald ];
  };
}
