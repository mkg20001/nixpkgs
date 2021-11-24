{ lib
, stdenv
, fetchFromGitHub
, cmake
, makeWrapper
, gawk
}:

stdenv.mkDerivation rec {
  pname = "cfs-zen-tweaks";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "igo95862";
    repo = "cfs-zen-tweaks";
    rev = version;
    sha256 = "HRR2tdjNmWyrpbcMlihSdb/7g/tHma3YyXogQpRCVyo=";
  };

  postPatch = ''
    patchShebangs .
  '';

  postInstall = ''
    chmod +x $out/lib/cfs-zen-tweaks/set-cfs-zen-tweaks.bash
    wrapProgram $out/lib/cfs-zen-tweaks/set-cfs-zen-tweaks.bash \
      --prefix PATH : ${gawk}/bin
  '';

  buildInputs = [
    gawk
  ];

  nativeBuildInputs = [
    cmake
    makeWrapper
  ];

  meta = with lib; {
    description = "Tweak Linux CPU scheduler for desktop responsiveness";
    homepage = "https://github.com/igo95862/cfs-zen-tweaks";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = with maintainers; [ mkg20001 ];
  };
}
