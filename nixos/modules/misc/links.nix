{ config, lib, pkgs, ... }:

with lib;

let
  joinPath = p:
    builtins.concatStringsSep "/" ([ "" ] ++ p);
  joinLines =
    builtins.concatStringsSep "\n";

  mkScript = links: joinLines (forEach links (link: let
    source = link.source;
    target = "/${link.target}";
  in
    ''
      mkdir -p "$(dirname ${escapeShellArg target})"
      ln -s ${escapeShellArgs [source target]}
    ''));
in
{
  options = {
    environment.links = mkOption {
      description = "Links to create";
      default = {};

      type = with types; loaOf (submodule (
        { name, config, ... }:
        { options = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = ''
                Whether this link should be generated.  This
                option allows specific links to be disabled.
              '';
            };

            target = mkOption {
              type = types.str;
              description = ''
                Path of the symlink. Defaults to the
                attribute name.
              '';
            };

            source = mkOption {
              type = types.path;
              description = "Path of the source file.";
            };
          };

          config = {
            target = mkDefault name;
          };

        }));
    };
  };

  config = (let
    links' = filter (f: f.enable) (attrValues config.environment.links);
  in
  mkIf (links' != [])
  {
    system.activationScripts.links = {
      text = mkScript links';
      deps = [ ]; # FIXME: add correct deps
    };
  });
}
