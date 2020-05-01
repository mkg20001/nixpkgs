{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.steam;
in {
  options.programs.steam = {
    enable = mkEnableOption "steam";
  };

  config = mkIf cfg.enable {
    hardware.opengl = { # glXchooseVisual failed https://github.com/NixOS/nixpkgs/issues/47932
      enable = true;
      driSupport32Bit = true;
    };

    hardware.steam-hardware.enable = true;

    environment.systemPackages = [ pkgs.steam ];
  };

  meta.maintainers = with maintainers; [ mkg20001 ];
}

