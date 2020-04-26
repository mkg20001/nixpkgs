{ stdenv
, fetchFromGitHub
, pkgconfig
, autoreconfHook
, glib
, gettext
, cinnamon-desktop
, intltool
, libxslt
, gtk3
, libnotify
, libxkbfile
, cinnamon-menus
, dbus-glib
, libgnomekbd
, libxklavier
, networkmanager
, libwacom
, gnome3
, libtool
, wrapGAppsHook
, tzdata
, glibc
, gobject-introspection
, python3
, pam
, accountsservice
, cairo
, xapps
, xorg
, dbus
, iso-flags-png-320x420
}:

stdenv.mkDerivation rec {
  pname = "cinnamon-screensaver";
  version = "4.4.0";

  src = fetchFromGitHub {
    owner = "linuxmint";
    repo = pname;
    rev = version;
    sha256 = "03v41wk1gmgmyl31j7a3pav52gfv2faibj1jnpj3ycwcv4cch5w5";
  };

  buildInputs = [
    # from configure.ac
    gobject-introspection
    gtk3
    glib

    xorg.libXext
    xorg.libXinerama
    xorg.libX11
    xorg.libXrandr

    (python3.withPackages (pp: with pp; [ pygobject3 setproctitle xapp pycairo ]))
    xapps
    pam
    accountsservice
    cairo
    cinnamon-desktop
    dbus

    # things
    iso-flags-png-320x420
  ];

  NIX_CFLAGS_COMPILE = "-I${glib.dev}/include/gio-unix-2.0"; # TODO: https://github.com/NixOS/nixpkgs/issues/36468

  postPatch = ''
    patchShebangs autogen.sh

    sed ${stdenv.lib.escapeShellArg "s&DBUS_SESSION_SERVICE_DIR=.*&DBUS_SESSION_SERVICE_DIR=`$PKG_CONFIG --variable session_bus_services_dir dbus-1 | sed -e 's,/usr/share,\${datarootdir},g' | sed 's|^|$out|'`&g"} -i configure.ac

    # cscreensaver hardcodes absolute paths everywhere. Nuke from orbit.
    find . -type f -exec sed -i \
      -e s,/usr/share/locale,/run/current-system/sw/share/locale,g \
      -e s,/usr/lib/cinnamon-screensaver,$out/lib,g \
      -e s,/usr/share/cinnamon-screensaver,$out/share,g \
      -e s,/usr/share/iso-flag-png,${iso-flags-png-320x420}/share/iso-flags-png,g \
      {} +

    sed "s|/usr/share/locale|/run/current-system/sw/share/locale|g" -i ./src/cinnamon-screensaver-main.py
  '';

  autoreconfPhase = ''
    NOCONFIGURE=1 bash ./autogen.sh
  '';

  postFixup = ''
    for f in $out/bin/*; do
      wrapProgram "$f" "--prefix" "GI_TYPELIB_PATH" ":" "$out/lib/girepository-1.0"
    done
  '';

  nativeBuildInputs = [
    pkgconfig
    autoreconfHook
    wrapGAppsHook
    gettext
    intltool
    libxslt
    libtool
  ];

  meta = with stdenv.lib; {
    homepage = "https://github.com/linuxmint/cinnamon-screensaver";
    description = "The Cinnamon screen locker and screensaver program";
    license = [ licenses.gpl2 licenses.lgpl2 ];
    platforms = platforms.linux;
    maintainers = [ maintainers.mkg20001 ];
  };
}
