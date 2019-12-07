{ pkgs, lib }:

lib.makeScope pkgs.newScope (self: with self; {
  cinnamon-common = callPackage ./cinnamon-common { };
  cinnamon-control-center = callPackage ./cinnamon-control-center { };
  cinnamon-desktop = callPackage ./cinnamon-desktop { };
  cinnamon-menus = callPackage ./cinnamon-menus { };
  cinnamon-translations = callPackage ./cinnamon-translations { };
  cinnamon-session = callPackage ./cinnamon-session { };
  cinnamon-settings-daemon = callPackage ./cinnamon-settings-daemon { };
  cinnamon-screensaver = callPackage ./cinnamon-screensaver { };
  cjs = callPackage ./cjs { };
  nemo = callPackage ./nemo { };
  muffin = callPackage ./muffin { };
  xapps = callPackage ./xapps { };
})
