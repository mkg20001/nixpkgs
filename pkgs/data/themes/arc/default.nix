{ lib, stdenv
, fetchFromGitHub
, sassc
, meson
, ninja
, glib
, gnome
, gnome-themes-extra
, gtk-engine-murrine
, inkscape
, cinnamon
, makeFontsConf
, python3
}:

stdenv.mkDerivation rec {
  pname = "arc-theme";
  version = "20221218";

  src = fetchFromGitHub {
    owner = "jnsh";
    repo = pname;
    rev = version;
    sha256 = "sha256-7VmqsUCeG5GwmrVdt9BJj0eZ/1v+no/05KwGFb7E9ns=";
  };

  nativeBuildInputs = [
    meson
    ninja
    sassc
    inkscape
    glib # for glib-compile-resources
    python3
    cinnamon.cinnamon-common
    gnome.gnome-shell
  ];

  propagatedUserEnvPkgs = [
    gnome-themes-extra
    gtk-engine-murrine
  ];

  postPatch = ''
    patchShebangs meson/install-file.py
    sed "s|cinnamon_versions = ['3.8', '4.0', '4.2', '4.4', '4.6', '4.8', '5.0', '5.2', '5.4']|cinnamon_versions = ['3.8', '4.0', '4.2', '4.4', '4.6', '4.8', '5.0', '5.2', '5.4', '6.0']|g" -i common/cinnamon/meson.build
  '';

  preBuild = ''
    # Shut up inkscape's warnings about creating profile directory
    export HOME="$TMPDIR"
  '';

  # Fontconfig error: Cannot load default config file: No such file: (null)
  FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ ]; };

  mesonFlags = [
    # "-Dthemes=cinnamon,gnome-shell,gtk2,gtk3,plank,xfwm,metacity"
    # "-Dvariants=light,darker,dark,lighter"
    "-Dcinnamon_version=6.0.0"
    "-Dgnome_shell_version=${gnome.gnome-shell.version}"
    # You will need to patch gdm to make use of this.
    "-Dgnome_shell_gresource=true"
  ];

  postInstall = ''
    install -Dm644 -t $out/share/doc/${pname} $src/AUTHORS $src/*.md
  '';

  meta = with lib; {
    description = "Flat theme with transparent elements for GTK 3, GTK 2 and Gnome Shell";
    homepage = "https://github.com/jnsh/arc-theme";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = with maintainers; [ simonvandel romildo ];
  };
}
