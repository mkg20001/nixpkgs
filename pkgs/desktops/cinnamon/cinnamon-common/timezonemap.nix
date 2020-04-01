{ stdenv
, autoreconfHook
, fetchbzr
, pkgconfig
, gtk3
, glib
, file
, gobject-introspection
, json_glib
, libsoup
}:

stdenv.mkDerivation rec {
  pname = "timezonemap";
  version = "0.4.5";

  src = fetchbzr {
    url = "lp:timezonemap";
    rev = "58";
    sha256 = "1qdp5f9zd8c02bf0mq4w15rlhz2g51phml5qg9asdyfd1715f8n0";
  };

  nativeBuildInputs = [
    pkgconfig
    autoreconfHook
  ];

  buildInputs = [
    gtk3
    glib
    gobject-introspection
    json_glib
    libsoup
  ];

  configureFlags = [
    "CFLAGS=-Wno-error"
    "--sysconfdir=/etc"
    "--localstatedir=/var"
  ];

  installFlags = [
    "sysconfdir=\${out}/etc"
    "localstatedir=\${TMPDIR}"
  ];

  preConfigure = ''
    for f in {configure,m4/libtool.m4}; do
      substituteInPlace $f\
        --replace /usr/bin/file ${file}/bin/file
    done
  '';

  postPatch = ''
    sed "s|/usr/share/libtimezonemap|$out/share/libtimezonemap|g" -i ./src/tz.h
  '';
}
