{ fetchFromGitHub
, stdenv
}:

stdenv.mkDerivation rec {
  pname = "mint-y-icons";
  version = "unstable-20200321";

  src = fetchFromGitHub {
    owner = "linuxmint";
    repo = pname;
    rev = "f169a617bc344cb0b480b2b72f54cdd06af05255";
    sha256 = "1c2a79ylk363i982czwwqcwc7cw6dyzlqphcypqm6nll7xlafq8s";
  };

  installPhase = ''
    mkdir -p $out
    mv usr/share $out
  '';

  meta = with stdenv.lib; {
    homepage = "https://github.com/linuxmint/mint-y-icons";
    description = "The Mint-Y icon theme";
    license = licenses.gpl3; # from debian/copyright
    platforms = platforms.linux;
    maintainers = [ maintainers.mkg20001 ];
  };
}
