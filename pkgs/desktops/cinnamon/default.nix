{ pkgs, lib }:

lib.makeScope pkgs.newScope (self: with self; {
  cjs = callPackage ./cjs { };
  nemo = callPackage ./nemo { };
  xapps = callPackage ./xapps { };
})
