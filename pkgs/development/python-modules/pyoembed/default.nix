{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  requests,
  beautifulsoup4,
  lxml,
}:

buildPythonPackage rec {
  pname = "pyoembed";
  version = "0.1.2";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-D3VcgwgDnx5JI46V6pTvFqoIrdnzIHW6E6ubZfMv9YI=";
  };

  build-system = [ setuptools ];

  dependencies = [
    requests
    beautifulsoup4
    lxml
  ];

  pythonImportsCheck = [ "pyoembed" ];

  meta = {
    description = "Python library for oEmbed that supports auto-discovered and manually included providers";
    homepage = "https://github.com/rafaelmartins/pyoembed";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ john-rodewald ];
  };
}
