{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.environment.links;

  joinPath = p:
    builtins.concatStringsSep "/" ([ "" ] ++ p);
  joinLines =
    builtins.concatStringsSep "\n";

  convertLinksRecursive = { attr, path ? [] }:
    builtins.concatMap (key:
      let
        newPath = path ++ [ key ];
        value = attr.${key};
      in
        if builtins.isAttrs value then
          [
            ''
              mkdir -p ${joinPath newPath}
            ''
          ] ++ (convertLinksRecursive { path = newPath; attr = value; })
        else if builtins.isString value then
          [
            ''
              ln -sfn ${value} ${joinPath newPath}.tmp
              rm -f ${joinPath newPath}
              mv ${joinPath newPath}.tmp ${joinPath newPath}
            ''
          ]
        else builtins.throw "Shell-Links got invalid value of non-attr/string type"
      ) (builtins.attrNames attr);
in
{
  options = {
    environment.links = {
      type = types.loaOf types.str;
      description = "Links to create";
      default = {};
    };
  };

  # iterate over keys:
  # path ? []
  # path push val
  # if isAttr val:
  #  mkdir -p ${path join "/"}
  #  iterate val, path
  # else if isString val:
  #  ln -sfn ${val} ${path join "/"}.tmp
  #  mv ${path join "/"}.tmp ${path join "/"}

  config = mkIf (cfg != {}) {
    system.activationScripts.links = {
      text = joinLines (convertLinksRecursive { attr = linkList; });
      deps = [ ]; # FIXME: add correct deps
    };
  };
}
