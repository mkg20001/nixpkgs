{ pkgs, lib }:

lib.makeScope pkgs.newScope (self: with self; {
  cinnamon-desktop = callPackage ./cinnamon-desktop { };
  cinnamon-menus = callPackage ./cinnamon-menus { };
  cinnamon-translations = callPackage ./cinnamon-translations { };
  cjs = callPackage ./cjs { };
  muffin = callPackage ./muffin { };
  nemo = callPackage ./nemo { };
  xapps = callPackage ./xapps { };
})
