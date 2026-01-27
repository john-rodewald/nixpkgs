{
  lib,
  python3,
  fetchFromGitHub,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "op1repacker";
  version = "0.2.5";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "op1hacks";
    repo = "op1repacker";
    tag = version;
    hash = "sha256-A/Hl/S3c1Wy6qdDDlaRBGxC8mDUI+2HYfvJBop+PWg8=";
  };

  build-system = with python3.pkgs; [ setuptools ];

  dependencies = with python3.pkgs; [ svg-path ];

  # No tests included in the repository
  doCheck = false;

  meta = {
    description = "Tool for unpacking, modding and repacking OP-1 firmware";
    homepage = "https://github.com/op1hacks/op1repacker";
    license = lib.licenses.mit;
    mainProgram = "op1repacker";
    maintainers = [ ];
  };
}
