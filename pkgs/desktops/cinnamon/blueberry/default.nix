{ stdenv
, wrapGAppsHook
, gettext
, file
, python3
, pavucontrol
, fetchFromGitHub
, rfkill
, gobject-introspection
, gnome3
, glib
}:

stdenv.mkDerivation rec {
  pname = "blueberry";
  version = "1.3.9";

  src = fetchFromGitHub {
    owner = "linuxmint";
    repo = pname;
    rev = version;
    sha256 = "0llvz1h2dmvhvwkkvl0q4ggi1nmdbllw34ppnravs5lybqkicyw9";
  };

  buildInputs = [
    rfkill
    glib
    pavucontrol
    (python3.withPackages(ps: with ps; [ pygobject3 setproctitle pydbus ]))
    gnome3.gnome-bluetooth
  ];

  nativeBuildInputs = [
    wrapGAppsHook
    gettext
    gobject-introspection
  ];

  postPatch = ''
    find . -type f -exec sed -i \
      -e s,/usr/lib/blueberry,$out/lib/blueberry,g \
      -e s,/usr/bin/pavucontrol,${pavucontrol}/bin/pavucontrol,g \
      -e s,/usr/share/locale,$out/share/locale,g \
      -e s,/usr/sbin/rfkill,${rfkill}/bin/rfkill,g \
      -e s,/usr/bin/rfkill,${rfkill}/bin/rfkill,g \
      {} +
  '';

  postFixUp = ''
    for f in "$out/bin/"*; do
      wrapProgram "$f" \
        --suffix XDG_DATA_DIRS : "$out/share:$out/share/gesttings-schemas/blueberry-1.3.9/glib-2.0/schemas:$GSETTINGS_SCHEMAS_PATH"
    done
  '';

  installPhase = ''
    mv usr $out
    mv etc $out/
  '';
}
