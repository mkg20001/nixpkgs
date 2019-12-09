{ pkgs, lib }:

lib.makeScope pkgs.newScope (self: with self;
  let
    version = "4.4.0";
    src = pkgs.fetchFromGitHub {
      owner = "linuxmint";
      repo = "nemo-extensions";
      rev = version;
      sha256 = "0hllb7a5rarv72a7kg56sbifa58jzcl2slkxxg9wn1gzpn6kwqv6";
    };
    call = file: callPackage file {
      wrap = args:
        let
        in
          {
            inherit src;
            inherit version;

            setSourceRoot = "sourceRoot=`pwd`/${args.pname}";
          } // args;
    };
  in
  {
  }
)
