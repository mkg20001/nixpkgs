{ stdenv
, lib
, fetchFromGitHub
, wrapGAppsHook
, python3
, gsettings-desktop-schemas
, gettext
, gtk3
, glib
, common-licenses
}:

stdenv.mkDerivation rec {
  pname = "bulky";
  version = "1.1";

  src = fetchFromGitHub {
    owner = "linuxmint";
    repo = "bulky";
    rev = version;
    sha256 = "NBlP10IM/+u8IRds4bdFyGWg3pJLRmlSLsdlndMVQqg=";
    fetchSubmodules = false;
  };

  nativeBuildInputs = [
    wrapGAppsHook
    gsettings-desktop-schemas
    gettext
  ];

  buildInputs = [
    (python3.withPackages(p: with p; [ pygobject3 magic setproctitle ]))
    gsettings-desktop-schemas
    gtk3
    glib
  ];

  postPatch = ''
    sed -e "s|/usr/share/locale|$out/share/locale|g"  \
        -e "s|/usr/share/bulky|$out/share/bulky|g" \
        -e "s|/usr/share/common-licenses|${common-licenses}/share/common-licenses|g" \
        -e "s|__DEB_VERSION__|${version}|g" \
        -i usr/lib/bulky/bulky.py
  '';

  installPhase = ''
    runHook preInstall
    chmod +x usr/share/applications/*
    cp -ra usr $out
    ln -sf $out/lib/bulky/bulky.py $out/bin/bulky
    runHook postInstall
  '';

  meta = with lib; {
    description = "Bulk rename app";
    homepage = "https://github.com/linuxmint/bulky";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = [ maintainers.mkg20001 ];
  };
}
