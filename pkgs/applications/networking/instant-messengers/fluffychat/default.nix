{ lib
, fetchFromGitLab
, flutter
, olm
}:

flutter.mkFlutterApp rec {
  pname = "fluffychat";
  # 42.3 is latest
  version = "0.41.2";

  vendorHash = "sha256-ccBECZoPaPahPlteAMvLCeWS6Cuzx/XgXjvxWAybJHE=";

  src = fetchFromGitLab {
    owner = "famedly";
    repo = "fluffychat";
    rev = "v${version}";
    hash = "sha256-3eAManOo+kzg16difcTRwWIFDU2hkxZDnLl7jr0b40M=";
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
