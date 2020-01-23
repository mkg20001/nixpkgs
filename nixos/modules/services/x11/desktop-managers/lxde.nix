{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.xserver.desktopManager.lxde;
in

{
  options = {
    services.xserver.desktopManager.lxde = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the LXDE desktop environment.";
      };
    };
  };

  config = mkIf cfg.enable { };
}
