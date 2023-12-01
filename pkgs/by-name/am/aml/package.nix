{ stdenv
, meson
, fetchFromGitHub
}:

stdenv.mkDerivation rec {
  pname = "aml";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "any1";
    repo = "aml";
    rev = "v${version}";
    hash = "sha256-BX+MRqvnwwLPhz22m0gfJ2EkW31KQEi/YTgOCMcQk2Q=";
  };

  nativeBuildInputs = [
    meson
  ];
}
