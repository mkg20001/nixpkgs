{ lib
, flutter
, fetchFromGitHub
}:

flutter.mkFlutterApp {
  pname = "firmware-updater";
  version = "unstable";

  vendorHash = "sha256-C6ePWAw4q8vyLaciHeIZphYCh22+oMrOwC7YNiQU7ic=";

  src = fetchFromGitHub {
    owner = "canonical";
    repo = "firmware-updater";
    rev = "856b430348f8ce6f889318e55cdd22945be470fb";
    sha256 = "IW0vvj04bKzLAmG9WYZvMVS2PSvLH1iftYI8fN5TbS0=";
    fetchSubmodules = true;
  };

  meta = with lib; {
    description = "Firmware Updater for Linux";
    homepage = "https://github.com/canonical/firmware-updater";
    license = licenses.free;
    maintainers = with maintainers; [ mkg20001 ];
    platforms = platforms.linux;
  };
}
