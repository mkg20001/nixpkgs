{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.xserver.desktopManager.cinnamon;

  nixos-gsettings-desktop-schemas = let
    defaultPackages = with pkgs; [ gsettings-desktop-schemas gnome3.gnome-shell ];
  in
  pkgs.runCommand "nixos-gsettings-desktop-schemas" { preferLocalBuild = true; }
    ''
     mkdir -p $out/share/gsettings-schemas/nixos-gsettings-overrides/glib-2.0/schemas

     ${concatMapStrings
        (pkg: "cp -rf ${pkg}/share/gsettings-schemas/*/glib-2.0/schemas/*.xml $out/share/gsettings-schemas/nixos-gsettings-overrides/glib-2.0/schemas\n")
        (defaultPackages ++ cfg.extraGSettingsOverridePackages)}

     cp -f ${pkgs.gnome3.gnome-shell}/share/gsettings-schemas/*/glib-2.0/schemas/*.gschema.override $out/share/gsettings-schemas/nixos-gsettings-overrides/glib-2.0/schemas

     chmod -R a+w $out/share/gsettings-schemas/nixos-gsettings-overrides
     cat - > $out/share/gsettings-schemas/nixos-gsettings-overrides/glib-2.0/schemas/nixos-defaults.gschema.override <<- EOF
       [org.gnome.desktop.background]
       picture-uri='file://${pkgs.nixos-artwork.wallpapers.simple-dark-gray}/share/artwork/gnome/nix-wallpaper-simple-dark-gray.png'

       [org.gnome.desktop.screensaver]
       picture-uri='file://${pkgs.nixos-artwork.wallpapers.simple-dark-gray-bottom}/share/artwork/gnome/nix-wallpaper-simple-dark-gray_bottom.png'

       [org.gnome.shell]
       favorite-apps=[ 'org.gnome.Epiphany.desktop', 'org.gnome.Geary.desktop', 'org.gnome.Music.desktop', 'org.gnome.Photos.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Software.desktop' ]

       ${cfg.extraGSettingsOverrides}
     EOF

     ${pkgs.glib.dev}/bin/glib-compile-schemas $out/share/gsettings-schemas/nixos-gsettings-overrides/glib-2.0/schemas/
    '';
in

{

  options = {
    services.xserver.desktopManager.cinnamon = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the Cinnamon desktop environment.";
      };

      extraGSettingsOverrides = mkOption {
        default = "";
        type = types.lines;
        description = "Additional gsettings overrides.";
      };

      extraGSettingsOverridePackages = mkOption {
        default = [];
        type = types.listOf types.path;
        description = "List of packages for which gsettings are overridden.";
      };
    };
  };

  config = mkIf cfg.enable {
    # Enable colord server
    services.colord.enable = mkDefault true;

    # Override GSettings schemas
    environment.sessionVariables.NIX_GSETTINGS_OVERRIDES_DIR = "${nixos-gsettings-desktop-schemas}/share/gsettings-schemas/nixos-gsettings-overrides/glib-2.0/schemas";

    environment.systemPackages = with pkgs.cinnamon // pkgs; [
      # common-files
      cinnamon-common
      cinnamon-session
      cinnamon-desktop

      # utils needed by some scripts
      pkgs.killall

      # session requirements
      cinnamon-screensaver
      # nemo-autostart: provided by nemo
      pkgs.gnome3.networkmanagerapplet
      # cinnamon-killer-daemon: provided by cinnamon-common

      # packages
      nemo
      cinnamon-control-center
      cinnamon-settings-daemon
      gnome3.libgnomekbd

      # theme
      pkgs.gnome3.adwaita-icon-theme
      pkgs.hicolor-icon-theme
      pkgs.gnome3.gnome-themes-extra
      pkgs.gnome3.gtk
    ];

    environment.pathsToLink = [
      "/share" # TODO: https://github.com/NixOS/nixpkgs/issues/47173
    ];

    fonts.fonts = with pkgs; [
      cantarell-fonts
      dejavu_fonts
      source-code-pro # Default monospace font in 3.32
      source-sans-pro
    ];

    services.xserver.desktopManager.session = [
      {
        name = "cinnamon";
        bgSupport = true;
        start = ''
          ${pkgs.runtimeShell} ${pkgs.cinnamon.cinnamon-common}/bin/cinnamon-session-cinnamon &
          waitPID=$!
        '';
      }
      {
        name = "cinnamon2d";
        bgSupport = true;
        start = ''
          ${pkgs.runtimeShell} ${pkgs.cinnamon.cinnamon-common}/bin/cinnamon-session-cinnamon2d &
          waitPID=$!
        '';
      }
    ];
  };
}
