{ lib
, fetchFromGitHub
, flutter
, webkitgtk
, libsysprof-capture
, sqlite
, libpsl
}:

flutter.mkFlutterApp rec {
  pname = "harmonoid";
  version = "0.1.8";

  vendorHash = "sha256-aDqRP24HzkgiuY08NmOMpZ3zB6vluwJ+gwUqO1fOr/8=";

  src = fetchFromGitHub {
    owner = pname;
    repo = pname;
    rev = "v${version}";
    hash = "sha256-5TkkG0sgkXb8Mz8QGy5TfO+KVedLJPZ9c34VBtLSVsc=";
  };

  buildInputs = [
    webkitgtk
    libsysprof-capture
    sqlite
    libpsl
  ];

  meta = with lib; {
    description = "Elegant music app to play local music & YouTube music. Distributes music into albums & artists";
    longDescription = ''
      Elegant music app to play local music & YouTube music.
      Distributes music into albums & artists.
      Has playlists & lyrics. Windows + Linux + Android.
    '';
    homepage = "https://github.com/harmonoid/harmonoid";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ mkg20001 ];
    platforms = platforms.linux;
  };
}
