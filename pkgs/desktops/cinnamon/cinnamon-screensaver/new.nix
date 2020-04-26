{ stdenv
, fetchFromGitHub
, pkgconfig
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
, meson
, ninja
, iso-flags-png-320x420
}:

stdenv.mkDerivation rec {
  pname = "cinnamon-screensaver";
  # version = "4.4.1";
  version = "unstable";

  src = fetchFromGitHub {
    owner = "linuxmint";
    repo = pname;
    # rev = version;
    rev = "d3db5dc37f8243c664f8b01d150e9a16c9f20184";
    sha256 = "1aqp0m6caysi2r3nsm13dgl2g6pnbfvlwvklg7s85rbq1jdb0vlz";
  };

  buildInputs = [
    # from meson.build
    gobject-introspection
    gtk3
    glib
    # gdk

    xorg.libXext
    xorg.libXinerama
    xorg.libX11
    xorg.libXrandr
    dbus
    pam

    # bindings
    (python3.withPackages (pp: with pp; [ pygobject3 setproctitle xapp pycairo ]))
    xapps
    accountsservice
    cairo
    cinnamon-desktop
    
    # things
    iso-flags-png-320x420
  ];

  NIX_CFLAGS_COMPILE = "-I${glib.dev}/include/gio-unix-2.0"; # TODO: https://github.com/NixOS/nixpkgs/issues/36468

  postPatch = ''
    # cscreensaver hardcodes absolute paths everywhere. Nuke from orbit.
    find . -type f -exec sed -i \
      -e s,/usr/share/locale,/run/current-system/sw/share/locale,g \
      -e s,/usr/lib/cinnamon-screensaver,$out/lib,g \
      -e s,/usr/share/cinnamon-screensaver,$out/share,g \
      -e s,/usr/share/iso-flag-png,${iso-flags-png-320x420}/share/iso-flags-png,g \
      {} +

    sed "s|/usr/share/locale|/run/current-system/sw/share/locale|g" -i ./src/cinnamon-screensaver-main.py
    sed -r "s|^dbus_services_dir = .*$|dbus_services_dir = prefix + dependency('dbus-1').get_pkgconfig_variable('session_bus_services_dir', define_variable: ['prefix', prefix])|g" -i meson.build
  '';

  postFixup = ''
    for f in $out/bin/*; do
      wrapProgram "$f" "--prefix" "GI_TYPELIB_PATH" ":" "$out/lib/girepository-1.0"
    done
  '';

  nativeBuildInputs = [
    pkgconfig
    wrapGAppsHook
    gettext
    libxslt
    meson
    ninja
  ];

  meta = with stdenv.lib; {
    homepage = "https://github.com/linuxmint/cinnamon-screensaver";
    description = "The Cinnamon screen locker and screensaver program ";
    license = [ licenses.gpl2 licenses.lgpl2 ];
    platforms = platforms.linux;
    maintainers = [ maintainers.mkg20001 ];
  };
}
