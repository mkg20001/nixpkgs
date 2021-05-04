{ rustPlatform
, fetchFromGitHub
, libsodium
, pkg-config
, stdenv
}:

rustPlatform.buildRustPackage {
  pname = "packetcrypt";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "cjdelisle";
    repo = "packetcrypt_rs";
    rev = "8491fa6c5530d86b03fe7c3b114b7e70e695d27e";
    hash = "sha256-yaMy3kUwLAvIyNScKY9Ll4g97enB2iyrIUC/k/aYEss=";
    fetchSubmodules = false;
  };

  cargoHash = "sha256-oJ5+Bses+DEfO3EN/A9dc3RNyJtqRTGwBZ0YoCVhhfU=";

  nativeBuildInputs = [
    pkg-config libsodium
  ];

  buildInputs = [
    libsodium
  ];
}
