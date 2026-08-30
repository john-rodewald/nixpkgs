{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  beautifulsoup4,
  html2text,
  importlib-metadata,
  lxml,
  pip,
  typing-extensions,
  zulip,
}:

buildPythonPackage rec {
  pname = "zulip-bots";
  version = "0.9.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "zulip";
    repo = "python-zulip-api";
    tag = version;
    hash = "sha256-mcqIfha+4nsqlshayLQ2Sd+XOYVKf1FkoczjiFRNybc=";
  };
  sourceRoot = "${src.name}/zulip_bots";

  build-system = [ setuptools ];

  dependencies = [
    beautifulsoup4
    html2text
    importlib-metadata
    lxml
    pip
    typing-extensions
    zulip
  ];

  pythonImportsCheck = [ "zulip_bots" ];

  meta = {
    description = "Framework and collection of bots for the Zulip message API";
    homepage = "https://github.com/zulip/python-zulip-api";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ john-rodewald ];
  };
}
