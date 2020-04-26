{ stdenv, fetchFromGitHub, sassc, autoreconfHook, pkgconfig, gtk3, gnome3
, gtk-engine-murrine, cinnamon, optipng, inkscape }:

stdenv.mkDerivation rec {
  pname = "arc-theme";
  version = "unstable-17042020";

  src = fetchFromGitHub {
    owner  = "jnsh";
    repo   = pname;
    rev    = "0779e1ca84141d8b443cf3e60b85307a145169b6";
    sha256 = "1ddyi8g4rkd4mxadjvl66wc0lxpa4qdr98nbbhm5abaqfs2yldd4";
  };

  nativeBuildInputs = [
    autoreconfHook
    pkgconfig
    sassc
    optipng
    inkscape
    gtk3
  ];

  propagatedUserEnvPkgs = [
    gnome3.gnome-themes-extra
    gtk-engine-murrine
  ];

  enableParallelBuilding = true;

  preBuild = ''
    # Shut up inkscape's warnings about creating profile directory
    export HOME="$NIX_BUILD_ROOT"
  '';

  configureFlags = [
    "--with-cinnamon=${cinnamon.cinnamon-common.version}"
    "--with-gnome-shell=${gnome3.gnome-shell.version}"
    "--disable-unity"
  ];

  postInstall = ''
    install -Dm644 -t $out/share/doc/${pname} AUTHORS *.md
  '';

  meta = with stdenv.lib; {
    description = "Flat theme with transparent elements for GTK 3, GTK 2 and Gnome Shell";
    homepage    = "https://github.com/jnsh/arc-theme";
    license     = licenses.gpl3;
    maintainers = with maintainers; [ simonvandel romildo ];
    platforms   = platforms.linux;
  };
}
