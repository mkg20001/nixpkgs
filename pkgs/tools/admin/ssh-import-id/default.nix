{ buildPythonPackage
, stdenv
, fetchgit
, requests
, makeWrapper
, extraHandlers ? []
}:

buildPythonPackage rec {
  pname = "ssh-import-id";
  version = "5.8";

  src = fetchgit {
    url = "https://git.launchpad.net/ssh-import-id";
    rev = version;
    sha256 = "0l9gya1hyf2qfidlmvg2cgfils1fp9rn5r8sihwvx4qfsfp5yaak";
  };

  propagatedBuildInputs = [
    requests
  ];

  nativeBuildInputs = [
    makeWrapper
  ];

  postFixup = ''
    for b in $out/bin/*; do
      # handlers require main bin, main bin requires handlers
      wrapProgram $b \
        --prefix PATH : "$out/bin:${stdenv.lib.makeBinPath extraHandlers}"
    done
  '';

  meta = with stdenv.lib; {
    description = "Retrieves an SSH public key and installs it locally";
    license = licenses.gpl3;
    maintainer = with maintainers; [ mkg20001 ];
    platforms = platforms.unix;
  };
}
