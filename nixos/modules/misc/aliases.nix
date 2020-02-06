{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.environment.aliases;

  createScript = key: value:
  let
    normalizedKey = key; # TODO: normalize
    script = ''#!${pkgs.bash}/bin/bash

set -euo pipefail

exec ${value}
'';
  in
    ''
      echo ${escapeShellArg script} > $out/bin/${escapeShellArg normalizedKey}
      chmod +x $out/bin/${escapeShellArg normalizedKey}
    '';
in
{
  options.environment.aliases = mkOption {
    type = types.attrsOf types.str;
    description = "Global binary aliases to create";
    default = {};
  };

  config = mkIf (cfg != {}) {
    environment.systemPackages = [
      (with pkgs; stdenv.mkDerivation {
        name = "aliases";

        dontUnpack = true;

        installPhase = ''
          mkdir -p $out/bin
          ${builtins.concatStringsSep "\n" (forEach (builtins.attrNames cfg) (key: createScript key cfg.${key}))}
        '';
      })
    ];
  };
}
