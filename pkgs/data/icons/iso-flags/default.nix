{ stdenv
, fetchFromGitHub
, perl
, perlPackages
, inkscape
, pngcrush
, librsvg
, targets ? [ "aöö" ]
}:

stdenv.mkDerivation {
  pname = "iso-flags";
  version = "unstable-18012020";

  src = fetchFromGitHub {
    owner = "joielechong";
    repo = "iso-country-flags-svg-collection";
    rev = "9ebbd577b9a70fbfd9a1931be80c66e0d2f31a9d";
    sha256 = "17bm7w4md56xywixfvp7vr3d6ihvxk3383i9i4rpmgm6qa9dyxdl";
  };

  nativeBuildInputs = [
    perl
    inkscape
    librsvg
  ] ++ (with perlPackages; [
    JSON
    XMLLibXML
  ]);
  
  postPatch = ''
    patchShebangs .
  '';
  
  buildPhase = ''
    make ${stdenv.lib.escapeShellArgs targets}
  '';
  
  installPhase = ''
    mkdir -p $out/share
    mv build $out/share/iso-flags
  '';
}
