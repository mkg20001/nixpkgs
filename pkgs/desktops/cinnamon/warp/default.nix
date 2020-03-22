{ fetchFromGitHub
, stdenv
, gobject-introspection
, meson
, ninja
, python3
, gtk3
, wrapGAppsHook
}:

stdenv.mkDerivation rec {
  pname = "warp";
  version = "unstable-20200321";

  src = fetchFromGitHub {
    owner = "linuxmint";
    repo = pname;
    rev = "5474cd974c2e4033f9f188fae5dbb0190eab796c";
    sha256 = "0gz5rp8j0c7bshcnvx8hvvpvsp0aisajc9qafv192zg8m0m2dh8w";
  };

  nativeBuildInputs = [
    meson
    ninja
    gobject-introspection
    wrapGAppsHook
  ];

  buildInputs = [
    gtk3
    (python3.withPackages (pp: with pp; [ grpcio-tools protobuf pygobject3 setproctitle xapp zeroconf grpcio setuptools ]))
  ];

  postPatch = ''
    chmod +x install-scripts/* bin/warp
    patchShebangs .
    sed "s|/usr|$out|g" -i bin/warp
    sed "s|\"python3\", ||g" -i bin/warp
  '';
}
