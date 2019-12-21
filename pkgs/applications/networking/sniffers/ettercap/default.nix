{ stdenv, fetchFromGitHub, fetchpatch, cmake, libpcap, libnet, zlib, curl, pcre
, openssl, ncurses, glib, gtk3, atk, pango, flex, bison, geoip, harfbuzz
, pkgconfig }:

stdenv.mkDerivation rec {
  pname = "ettercap";
  version = "0.8.3";

  src = fetchFromGitHub {
    owner = "Ettercap";
    repo = "ettercap";
    rev = "v${version}";
    sha256 = "0m40bmbrv9a8qlg54z3b5f8r541gl9vah5hm0bbqcgyyljpg39bz";
  };

  patches = [
    (fetchpatch {
      url = "https://github.com/Ettercap/ettercap/compare/ebc85131c656ea13907195b6e1981e0f8c121c50...78da46d1488fa9903344fc993555461f54ae9c6a.diff";
      sha256 = "02nzps4ca3d20gvykyaz8qjnsgjvks2czfmq8ic9xk17v2pn19ji";
    })
  ];

  strictDeps = true;
  nativeBuildInputs = [ cmake flex bison pkgconfig ];
  buildInputs = [
    libpcap libnet zlib curl pcre openssl ncurses
    glib gtk3 atk pango geoip
    harfbuzz
  ];

  preConfigure = ''
    substituteInPlace CMakeLists.txt --replace /etc \$\{INSTALL_PREFIX\}/etc \
                                     --replace /usr \$\{INSTALL_PREFIX\}
  '';

  cmakeFlags = [
    "-DBUNDLED_LIBS=Off"
    "-DGTK3_GLIBCONFIG_INCLUDE_DIR=${glib.out}/lib/glib-2.0/include"
  ];

  meta = with stdenv.lib; {
    description = "Comprehensive suite for man in the middle attacks";
    homepage = http://ettercap.github.io/ettercap/;
    license = licenses.gpl2;
    platforms = platforms.unix;
    maintainers = with maintainers; [ pSub ];
  };
}
