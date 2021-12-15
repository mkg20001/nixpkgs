{ lib
, fetchFromGitLab
, flutter
, olm
}:

flutter.mkFlutterApp rec {
  pname = "fluffychat";
  version = "1.0.1";

  vendorHash = "sha256-wYwYN0xi86x6fcFSVCgpj6ndeOBc1uMSLm+ViqspvSg=";

  src = fetchFromGitLab {
    owner = "famedly";
    repo = "fluffychat";
    rev = "v${version}";
    hash = "sha256-KXQUmplkY16qsFlGN5cYSEKs95iUwHwe2SMcfADMarI=";
  };

  buildInputs = [
    olm
  ];

  meta = with lib; {
    description = "Chat with your friends (matrix client)";
    homepage = "https://fluffychat.im/";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [ mkg20001 ];
    platforms = platforms.linux;
  };
}
