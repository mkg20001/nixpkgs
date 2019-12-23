{ mkDerivation
, python3
, fetchurl
, lib
, pulseaudio
}:

let
  qp = "./src/utils/qpaeq";
in
mkDerivation rec {
  pname = "pulseuadio-qpaeq-${version}";
  version = "13.0";

  /* src = fetchurl {
    url = "http://freedesktop.org/software/pulseaudio/releases/pulseaudio-${version}.tar.xz";
    sha256 = "0mw0ybrqj7hvf8lqs5gjzip464hfnixw453lr0mqzlng3b5266wn";
  }; */

  src = ./.;

  buildInputs = [
    (
      (python3.withPackages(ps: with ps; [ pyqt5 dbus-python sip ]))
      .override(args: { ignoreCollisions = true; })
    )
  ];

  nativeBuildInputs = [
    pulseaudio.out
  ];

  installPhase = ''
    install -D ${qp} $out/bin/qpaeq
    '';

  postPatch = ''
    mkdir -p "$(dirname "${qp}")"
    cp ${pulseaudio.out}/bin/qpaeq ${qp}

    sed 's|dbus.mainloop.pyqt5|dbus.mainloop.glib|g' -i ${qp}
    sed 's|DBusQtMainLoop|DBusGMainLoop|g' -i ${qp}
    '';

  preFixup = ''
    wrapQtApp $out/bin/qpaeq
    '';

  meta = {
    description = "Sound server for POSIX and Win32 systems";
    homepage    = http://www.pulseaudio.org/;
    license     = lib.licenses.lgpl2Plus;
    maintainers = with lib.maintainers; [ lovek323 ];
    platforms   = lib.platforms.unix;

    longDescription = ''
      PulseAudio is a sound server for POSIX and Win32 systems.  A
      sound server is basically a proxy for your sound applications.
      It allows you to do advanced operations on your sound data as it
      passes between your application and your hardware.  Things like
      transferring the audio to a different machine, changing the
      sample format or channel count and mixing several sounds into
      one are easily achieved using a sound server.
    '';
  };
}
