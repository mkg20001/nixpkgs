{
  lib,
  stdenv,
  fetchFromGitLab,
  cmake,
}:

stdenv.mkDerivation rec {
  pname = "olm";
  version = "3.2.16";

  src = fetchFromGitLab {
    domain = "gitlab.matrix.org";
    owner = "matrix-org";
    repo = "olm";
    rev = version;
    sha256 = "sha256-JX20mpuLO+UoNc8iQlXEHAbH9sfblkBbM1gE27Ve0ac=";
  };

  nativeBuildInputs = [ cmake ];

  doCheck = true;

  postPatch =
    ''
      substituteInPlace olm.pc.in \
        --replace '$'{exec_prefix}/@CMAKE_INSTALL_LIBDIR@ @CMAKE_INSTALL_FULL_LIBDIR@ \
        --replace '$'{prefix}/@CMAKE_INSTALL_INCLUDEDIR@ @CMAKE_INSTALL_FULL_INCLUDEDIR@
    ''
    # Clang 19 has become more strict about assigning to const variables
    # Patch from https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=281497
    + lib.optionalString (stdenv.cc.isClang && lib.versionAtLeast stdenv.cc.version "19") ''
      substituteInPlace include/olm/list.hh \
        --replace-fail "T * const other_pos = other._data;" "T const * other_pos = other._data;"
    '';

  meta = with lib; {
    description = "Implements double cryptographic ratchet and Megolm ratchet";
    homepage = "https://gitlab.matrix.org/matrix-org/olm";
    license = licenses.asl20;
    maintainers = with maintainers; [
      tilpner
      oxzi
    ];
    knownVulnerabilities = [];
  };
}
