{ stdenv
, aml
, wayland
, libxkbcommon
, pixman
, meson
, ninja
, pkg-config
, wayland-protocols
, fetchFromGitHub
, libdrm
, rPackages
, cmake
, libGL
, ffmpeg
, openssl
, libjpeg
, libpng
, lzo
, zlib
, clangStdenv
}:

#clangStdenv.mkDerivation rec {
stdenv.mkDerivation rec {
  pname = "wlvncc";
  version = "unstable";

  src = fetchFromGitHub {
    owner = "any1";
    repo = "wlvncc";
    rev = "2b9a886edd38204ef36e9f9f65dd32aaa3784530";
    hash = "sha256-0HbZEtDaLjr966RS+2GHc7N4nsivPIv57T/+AJliwUI=";
  };

  postPatch = ''
    sed "s|.*gbm.*||g" -i meson.build
  '';

  env.NIX_CFLAGS_COMPILE = toString ([
    "-Wno-error=deprecated-declarations"
#    "-lvector"
  ]);

  buildInputs = [
    aml
    wayland
    libxkbcommon
    pixman
    libdrm
    rPackages.gbm
    libGL
    ffmpeg
    openssl
    libjpeg
    libpng
    lzo
    zlib
/*Run-time dependency openssl found: NO (tried pkgconfig, system and cmake)
Run-time dependency gnutls found: NO (tried pkgconfig and cmake)
Run-time dependency libsasl2 found: NO (tried pkgconfig and cmake)
Run-time dependency libjpeg found: NO (tried pkgconfig and cmake)
Run-time dependency libpng found: NO (tried pkgconfig and cmake)
Run-time dependency lzo2 found: NO (tried pkgconfig and cmake)
Run-time dependency zlib found: NO (tried pkgconfig, cmake and system)*/

  ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    cmake
  ];
}
