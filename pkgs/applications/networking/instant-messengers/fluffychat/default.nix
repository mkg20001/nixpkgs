{ lib
, fetchFromGitLab
, flutter
, olm
}:

flutter.mkFlutterApp rec {
  pname = "fluffychat";
  version = "1.2.0";

  vendorHash = "sha256-slQeCECItZirEVf3agB8mqhTg6/JLsErFV2yDj4M3k0=";

  src = fetchFromGitLab {
    owner = "famedly";
    repo = "fluffychat";
    rev = "v${version}";
    hash = "sha256-PJH3jMQc6u9R6Snn+9rNN8t+8kt6l3Xt7zKPbpqj13E=";
  };

  buildInputs = [
    olm
  ];

  flutterExtraFetchCommands = ''
    M=$(echo $TMP/.pub-cache/hosted/pub.dartlang.org/matrix-*)
    sed "s|/usr/lib/x86_64-linux-gnu/libolm.so.3|${olm}/lib/libolm.so.3|g" -i $M/scripts/prepare.sh
    sed "s|if which flutter >/dev/null; then|exit; if which flutter >/dev/null; then|g" -i $M/scripts/prepare.sh

    # debug
    # cat $M/scripts/prepare.sh

    pushd $M
    chmod +x ./scripts/*.sh
    ./scripts/prepare.sh
    popd
  '';

  meta = with lib; {
    description = "Chat with your friends (matrix client)";
    homepage = "https://fluffychat.im/";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [ mkg20001 ];
    platforms = platforms.linux;
  };
}
