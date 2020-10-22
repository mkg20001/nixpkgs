with (import ./. {});

stdenv.mkDerivation {
  name = "lotus";
  version = "0.0.0";
  
  nativeBuildInputs = [
    cargo
    rustc
    go
    git
    # bzr
    jq
    pkg-config
    rustup
  ];
  
  configurePhase = ''
    # absolute paths everywhere. Nuke from orbit.
    find . -type f -exec sed -i \
      -e s,/usr/bin/env,${coreutils}/bin/env,g \
      -e s,'git submodule update --init --recursive',,g \
    # error: no such subcommand: `+1.43.1` is because non-rustup version is used
      -e s,'cargo +$2','cargo',g \
      {} +

    patchShebangs .
    export RUSTFLAGS="-C target-cpu=native -g"
    export FFI_BUILD_FROM_SOURCE=1

    # something about missing attrsets
    # export CGO_CFLAGS_ALLOW="-D__BLST_PORTABLE__"
    # export CGO_CFLAGS="-D__BLST_PORTABLE__"
  '';

  buildPhase = ''
    make
  '';

  installPhase = ''
    make install PREFIX=\$(out)
  '';
  
  buildInputs = [
    opencl-icd
    opencl-headers
  ];

  src = fetchFromGitHub {
    owner = "filecoin-project";
    repo = "lotus";
    rev = "a6b2180756db71574b385ef3c357f2b943252e78";
    sha256 = "143r7wyvkrvqx4vmb8744fjj3vndsbhzn99mnmd37n6lglwqah8s";
    fetchSubmodules = true;
    leaveDotGit = true;
  };
}

# gcc git bzr jq pkg-config opencl-icd-loader opencl-headers
