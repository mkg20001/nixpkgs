# New rust versions should first go to staging.
# Things to check after updating:
# 1. Rustc should produce rust binaries on x86_64-linux, aarch64-linux and x86_64-darwin:
#    i.e. nix-shell -p fd or @GrahamcOfBorg build fd on github
#    This testing can be also done by other volunteers as part of the pull
#    request review, in case platforms cannot be covered.
# 2. The LLVM version used for building should match with rust upstream.
# 3. Firefox and Thunderbird should still build on x86_64-linux.

{ stdenv, lib
, buildPackages
, newScope, callPackage
, CoreFoundation, Security
, llvmPackages_5
, pkgsBuildTarget, pkgsBuildBuild
} @ args:

import ./default.nix {
  rustcVersion = "1.43.0";
  rustcSha256 = "18akhk0wz1my6y9vhardriy2ysc482z0fnjdcgs9gy59kmnarxkm";

  # Note: the version MUST be one version prior to the version we're
  # building
  bootstrapVersion = "1.42.0";

  # fetch hashes by running `print-hashes.sh 1.43.0`
  bootstrapHashes = {
i686-unknown-linux-gnu = "c532385b79fa97144367a7f785f1d8437341099e7b2f065b1ae0b6938ff9b53c";
x86_64-unknown-linux-gnu = "069f34fa5cef92551724c83c36360df1ac66fe3942bc1d0e4d341ce79611a029";
arm-unknown-linux-gnueabihf = "da6b19d4e4a4818df46d2d2dca5fd83e073b86179158fdda8af2419f8bc9ebe7";
armv7-unknown-linux-gnueabihf = "cdcabf05bfe2c527fb95a7282ea79aae5215cc362a44ab35ee2b9fbc03d3e4c4";
aarch64-unknown-linux-gnu = "e5fa55f333c10cdae43d147438a80ffb435d6c7b9681cd2e2f0857c024556856";
x86_64-apple-darwin = "504e8efb2cbb36f5a3db7bb36f339a1e5216082c910ad19039c370505cfbde99";
  };

  selectRustPackage = pkgs: pkgs.rust_1_43_1;

  rustcPatches = [
  ];
}

(builtins.removeAttrs args [ "fetchpatch" ])
