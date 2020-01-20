{ fetchFromGitHub
, autoreconfHook
, cinnamon-desktop
, glib
, gnome3
, gnome-doc-utils
, fetchpatch
, gobject-introspection
, gtk3
, intltool
, json-glib
, libinput
, libstartup_notification
, libXtst
, libxkbcommon
, pkgconfig
, stdenv
, udev
, xorg
, wrapGAppsHook
, pango
, cairo
, gtk-doc
, docbook_xsl
, docbook_xml_dtd_43
, docbook_xml_dtd_42
, docbook_xml_dtd_412
}:

# it's a frankensteins monster with some cinnamon sparkles added on top of it

stdenv.mkDerivation rec {
  pname = "muffin";
  version = "4.4.2";

  src = fetchFromGitHub {
    owner = "linuxmint";
    repo = pname;
    rev = version;
    sha256 = "1kzjw4a5p69j8x55vpbpn6gy8pkbbyii6kzw2nzbypmipgnnijw8";
  };

  patches = [
    # https://github.com/linuxmint/muffin/pull/548
    ./egl.patch
    (fetchpatch { # https://github.com/linuxmint/muffin/issues/535#issuecomment-536917143
      url = "https://src.fedoraproject.org/rpms/muffin/blob/master/f/0001-fix-warnings-when-compiling.patch";
      sha256 = "15wdbn3afn3103v7rq1icp8n0vqqwrrya03h0g2rzqlrsc7wrvzw";
    })
  ];

  buildInputs = [
    gtk3
    glib
    pango
    cairo
    json-glib
    cinnamon-desktop
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libxkbfile
    xorg.xkeyboardconfig

    libxkbcommon
    gnome3.zenity
    gnome-doc-utils
    libinput
    libstartup_notification
    libXtst
    udev
    gobject-introspection
  ];

  nativeBuildInputs = [
    autoreconfHook
    wrapGAppsHook
    pkgconfig
    intltool

    gtk-doc
    docbook_xsl
    docbook_xml_dtd_43
    docbook_xml_dtd_42
    docbook_xml_dtd_412
  ];

  preAutoreconf = "NOCONFIGURE=1 ./autogen.sh";

  meta = with stdenv.lib; {
    homepage = "https://github.com/linuxmint/muffin";
    description = "The window management library for the Cinnamon desktop (libmuffin) and its sample WM binary (muffin)";
    license = licenses.gpl2;
    platforms = platforms.linux;
    maintainers = [ maintainers.mkg20001 ];
  };
}
