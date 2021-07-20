{ stdenv
, lib
, fetchFromGitHub
, fetchpatch
, cmake
, wxGTK
, pkg-config
, python3
, gettext
, file
, libvorbis
, libmad
, libjack2
, lv2
, lilv
, serd
, sord
, sqlite
, sratom
, suil
, alsa-lib
, libsndfile
, soxr
, flac
, twolame
, expat
, libid3tag
, libopus
, ffmpeg
, soundtouch
, pcre /*, portaudio - given up fighting their portaudio.patch */
, linuxHeaders
, at-spi2-core
, dbus
, epoxy
, libXdmcp
, libXtst
, libpthreadstubs
, libselinux
, libsepol
, libxkbcommon
, util-linux
, conan
, ninja
, zlib
, libpng
, libjpeg
, lame
, rapidjson
, vamp-plugin-sdk
, libogg
, portmidi
}:

# -- Conan: Adding audacity remote repository (https://artifactory.audacityteam.org/artifactory/api/conan/conan-local) verify ssl (True)
/* -- Adding Conan dependency ZLIB
-- Adding Conan dependency expat
-- Adding Conan dependency wxWidgets
-- Adding Conan dependency libmp3lame
-- Adding Conan dependency libid3tag
-- Adding Conan dependency libmad
-- Adding Conan dependency ThreadPool
-- Adding Conan dependency libuuid
-- Adding Conan dependency RapidJSON */


# TODO
# 1. as of 3.0.2, GTK2 is still the recommended version ref https://www.tenacityteam.org/download/source/ check if that changes in future versions
# 2. detach sbsms

let
  inherit (lib) optionals;

  wxGTK' = wxGTK.overrideAttrs (oldAttrs: rec {
    src = fetchFromGitHub {
      owner = "audacity";
      repo = "wxWidgets";
      rev = "07e7d832c7a337aedba3537b90b2c98c4d8e2985";
      sha256 = "1mawnkcrmqj98jp0jxlnh9xkc950ca033ccb51c7035pzmi9if9a";
      fetchSubmodules = true;
    };
  });

in
stdenv.mkDerivation rec {
  pname = "tenacity";
  version = "unstable-07-07-21";

  src = fetchFromGitHub {
    owner = "tenacityteam";
    repo = "tenacity";
    # rev = "Tenacity-${version}";
    rev = "c3eaa8650d4d7800e6f92e50836add5acf16304f";
    sha256 = "qFRE8KgzI3jJPF/abusok8QVmqTWlLVq+FXwf2XX5Vw=";
  };

  patches = [
    ./xdg.patch
    (fetchpatch {
      url = "https://github.com/tenacityteam/tenacity/pull/173.patch";
      sha256 = "dxPPFoHq+axigAfxFNdKOQ0RQ/o6ir75pSkpjU6Gz+g=";
    })
  ];

  postPatch = ''
    touch src/RevisionIdent.h

    substituteInPlace src/FileNames.cpp \
      --replace /usr/include/linux/magic.h ${linuxHeaders}/include/linux/magic.h

    substituteInPlace cmake-proxies/cmake-modules/AudacityDependencies.cmake \
      --replace 'conan_add_remote(NAME audacity
    URL https://artifactory.audacityteam.org/artifactory/api/conan/conan-local
    VERIFY_SSL True
)' ""

    # rm cmake-proxies/cmake-modules/conan.cmake
    # rm cmake-proxies/cmake-modules/AudacityDependencies.cmake
    # sed "s|resolve_conan_dependencies()|# resolve_conan_dependencies()|g" -i CMakeLists.txt
  '';

  # tenacity only looks for ffmpeg at runtime, so we need to link it in manually
  /* NIX_LDFLAGS = toString [
    "-lavcodec"
    "-lavdevice"
    "-lavfilter"
    "-lavformat"
    "-lavresample"
    "-lavutil"
    "-lpostproc"
    "-lswresample"
    "-lswscale"
  ]; */

  cmakeFlags = [
    "-Dobey_system_dependencies=on"
    "-Dlib_preference=system"
    "-Duse_ffmpeg=linked"
    "-Duse_flac=system"
    "-Duse_id3tag=system"
    "-Duse_libmad=system"
    "-Duse_libmp3lame=system"
    "-Duse_lv2=system"
    "-Duse_mad=system"
    "-Duse_midi=system"
    # "-Duse_nyquist=off"
    # "-Duse_nyquist=system"
    "-Duse_ogg=system"
    # "-Duse_portmixer=off"
    "-Duse_portsmf=system"
    "-Duse_sbsms=system"
    "-Duse_sndfile=system"
    "-Duse_soundtouch=system"
    "-Duse_soxr=system"
    "-Duse_sqlite=system"
    "-Duse_twolame=system"
    "-Duse_vamp=system"
    "-Duse_vorbis=system"
    "-Duse_wxwidgets=system"
    "-Duse_zlib=system"
    "-Duse_curl=system"
  ];

  nativeBuildInputs = [
    cmake
    ninja
    gettext
    pkg-config
    python3
    conan
  ] ++ optionals stdenv.isLinux [
    linuxHeaders
  ];

  buildInputs =  [
    zlib
    expat
    libpng
    libjpeg
    wxGTK'
    wxGTK'.gtk
    lame.out
    lame.lib
    lame.dev
    libid3tag
    libmad
    util-linux # uuid
    # libpthreadstubs # ThreadPool
    rapidjson
    libsndfile
    libopus
    flac
    soxr
    libjack2
    sqlite
    alsa-lib
    ffmpeg
    vamp-plugin-sdk
    libogg
    libvorbis
    lilv
    lv2
    serd
    sord
    sratom
    suil
    portmidi
  ] /*[
    alsa-lib
    expat
    ffmpeg
    file
    flac
    libid3tag
    libjack2
    libmad
    libopus
    libsndfile
    libvorbis
    lilv
    lv2
    pcre
    serd
    sord
    soundtouch
    soxr
    sqlite
    sratom
    suil
    twolame
    wxGTK'
    wxGTK'.gtk
  ] ++ optionals stdenv.isLinux [
    at-spi2-core
    dbus
    epoxy
    libXdmcp
    libXtst
    libpthreadstubs
    libxkbcommon
    libselinux
    libsepol
    util-linux
  ] */;

  doCheck = false; # Test fails

  meta = with lib; {
    description = "Sound editor with graphical UI";
    homepage = "https://tenacityaudio.org/";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ mkg20001 ];
    platforms = platforms.linux;
  };
}
