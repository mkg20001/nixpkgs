{ stdenv
, fetchFromGitHub
, bash
}:
stdenv.mkDerivation rec {
  pname = "docker-clean";
  version = "2.0.4";

  src = fetchFromGitHub {
    owner = "ZZRotDesign";
    repo = pname;
    rev = "v${version}";
    sha256 = "18wpni2jhwaldhld3x6kfmni1z6bvgc2725wc28af6cj5y0imc64";
  };

  buildInputs = [
    bash
  ];

  installPhase = ''
    install -D docker-clean $out/bin/docker-clean
    '';

  meta = with stdenv.lib; {
    description = "A script that cleans docker containers, images, volumes, and networks";
    homepage = "https://github.com/ZZROTDesign/docker-clean";
    license = licenses.mit;
    maintainers = [ maintainers.mkg20001 ];
    platforms = platforms.linux;
  };
}
