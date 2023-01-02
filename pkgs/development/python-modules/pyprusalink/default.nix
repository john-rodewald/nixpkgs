{ lib
, httpx
, buildPythonPackage
, fetchFromGitHub
, pythonOlder
, setuptools
}:

buildPythonPackage rec {
  pname = "pyprusalink";
  version = "1.2.0";
  format = "pyproject";

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "john-rodewald";
    repo = pname;
    rev = "refs/tags/${version}";
    hash = "0aqq8b1awwy367r3zxydls3cr2k4j71aca1xdx190aj2nbij3smj";
  };

  nativeBuildInputs = [
    setuptools
  ];

  propagatedBuildInputs = [
    httpx
  ];

  # Module doesn't have tests
  doCheck = false;

  pythonImportsCheck = [
    "pyprusalink"
  ];

  meta = with lib; {
    description = "Library to communicate with PrusaLink ";
    homepage = "https://github.com/john-rodewald/pyprusalink";
    license = with licenses; [ asl20 ];
    maintainers = with maintainers; [ fab ];
  };
}
