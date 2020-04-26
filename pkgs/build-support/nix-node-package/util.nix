{ lib, fetchurl }:
  let
    # internal
    and = a: b:
      if a then
        if b then true else false
      else false;

    recursiveIterateRecreate = set: iter:
      builtins.listToAttrs(
        builtins.concatMap iter (builtins.attrNames set)
      );

    # private util
    recursiveIterateReplace = deps: opts:
      recursiveIterateRecreate deps (name:
        if and (lib.hasAttrByPath [name "dev"] deps) opts.production then
          [] # skip dev
        else
          [(lib.nameValuePair name (recursiveReplaceResolved deps.${name} opts))]
      );

    recursiveReplaceResolved = pkg: opts:
      recursiveIterateRecreate pkg (name:
        if name == "resolved" then # else change the resolved url to a resolved hash
          let
            hash = builtins.match "^([a-z0-9]+)-(.+)$" pkg.integrity;
            fetched = fetchurl {
              url = pkg.resolved;
              ${builtins.elemAt hash 0} = builtins.elemAt hash 1;
            };
          in
            [(lib.nameValuePair name "file://${fetched}")]
        else if name == "version" && lib.hasPrefix "http" pkg.version then # else change the resolved url (that is the versino) to a resolved hash
          let
            hash = builtins.match "^([a-z0-9]+)-(.+)$" pkg.integrity;
            fetched = fetchurl {
              url = pkg.version;
              ${builtins.elemAt hash 0} = builtins.elemAt hash 1;
            };
          in
            [(lib.nameValuePair name pkg.version) (lib.nameValuePair "resolved" "file://${fetched}")]
        else if name == "dependencies" then
          [(lib.nameValuePair name (recursiveIterateReplace pkg.dependencies opts))]
        else
          [(lib.nameValuePair name pkg.${name})]
      );

    recreateLockfile = lock: opts:
      recursiveIterateRecreate lock (name:
        if name == "dependencies" then
          [(lib.nameValuePair name (recursiveIterateReplace lock.dependencies opts))]
        else
          [(lib.nameValuePair name lock.${name})]
    );

    # public util
    prepareLockfile = json: production:
      let
        newJson = recreateLockfile json { production = production; };
      in
        builtins.toJSON newJson;
  in {
    prepareLockfile = prepareLockfile;
    concatAttrs = a: b: # just a level-1 concat for lists only, due to perf
      a // recursiveIterateRecreate b (key:
        if lib.hasAttrByPath [ key ] a && builtins.isList a.${key} && builtins.isList b.${key} then
          [(lib.nameValuePair key (a.${key} ++ b.${key}))]
        else
          [(lib.nameValuePair key b.${key})]
      );
  }
