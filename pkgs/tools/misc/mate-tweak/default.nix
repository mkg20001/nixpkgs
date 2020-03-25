{ stdenv
, fetchFromGitHub
, python3
, intltool
, mate
, libnotify
, gtk3
, gobject-introspection
, wrapGAppsHook
, glib
}:

python3.pkgs.buildPythonApplication rec {
  pname = "mate-tweak";
  version = "20.04.0";

  src = fetchFromGitHub {
    owner = "ubuntu-mate";
    repo = pname;
    rev = version;
    sha256 = "14cvh5hf61s0z75skrpz6r0z27jd01z100v2cqih2ck0pxv0483v";
  };

  nativeBuildInputs = [
    wrapGAppsHook
    intltool
    (python3.withPackages(ps: with ps; [ distutils_extra ]))
    gobject-introspection
  ];

  buildInputs = [
    gtk3
    libnotify
    glib
    mate.mate-applets
    mate.mate-panel
    mate.marco
    mate.libmatekbd
  ];

  strictDeps = false;

  dontWrapGApps = true;

  # Arguments to be passed to `makeWrapper`, only used by buildPython*
  preFixup = ''
    makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  prePatch = ''
    # mate-tweak hardcodes absolute paths everywhere. Nuke from orbit.
    find . -type f -exec sed -i \
      -e s,/usr/lib/mate-tweak,$out/lib/mate-tweak,g \
      {} +
  '';

  preDistPhases = [ "fixPaths" ];

  fixPaths = ''
    dataLoc=$(echo "$out/${python3.sitePackages}/nix/store/"*)
    mv -v $dataLoc/share/* $out/share
    mv -v $dataLoc/lib/* $out/lib
  '';

  postFixup = ''
    sed -i "s|usr|run/current-system/sw|g" $out/bin/.mate-tweak-wrapped
  '';

  propagatedBuildInputs = with python3.pkgs; [
    distro
    pygobject3
    psutil
    setproctitle
  ];

  meta = with stdenv.lib; {
    description = "Tweak tool for the MATE Desktop";
    homepage = "https://github.com/ubuntu-mate/${pname}";
    changelog = "https://github.com/ubuntu-mate/${pname}/releases/tag/${version}";
    license = [ licenses.gpl2 ];
    platforms = platforms.linux;
    maintainers = with maintainers; [ luc65r ];
  };
}
