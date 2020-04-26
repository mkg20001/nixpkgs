{ lib
, fetchurl
, stdenv
, jq
, nukeReferences
, writeText
, python3
, ...
}:
  with lib;
  with (import ./util.nix { lib = lib; fetchurl = fetchurl; });
  let
    makeNode = {
      root,
      packageLock ? null,
      yarnLock ? null,

      nodejs,
      production ? true,
      build ? true,
      buildProduction ? false
    }: attrs:
      let
        # code
        jsonFile = if (packageLock != null) then packageLock else "${root}/package-lock.json"; # TODO: yarn.lock
        json = builtins.fromJSON(builtins.readFile jsonFile); # TODO: also support yarn.lock
        lockfilePrepared = prepareLockfile json (production && buildProduction);
        safename = builtins.replaceStrings ["@" "/"] ["" "-"] json.name;
        tarball = "${safename}-${json.version}.tgz";
      in
        stdenv.mkDerivation(concatAttrs {
          pname = safename;
          version = json.version;

          src = root;

          buildInputs = [ nodejs ];

          nativeBuildInputs = [ jq nukeReferences python3 ];

          prePhases = [ "nodeExports" ];

          nodeExports = ''
            # fix update check failed errors
            export NO_UPDATE_NOTIFIER=true
          '';

          preBuildPhases = [ "nodeGypHeaders" "nodeBuildPhase" ];

          nodeGypHeaders = ''
            NODE_VERSION=$(node --version | sed "s|v||g")
            GYP_FOLDER="/tmp/.cache/node-gyp/$NODE_VERSION"
            mkdir -p "$GYP_FOLDER"
            ln -s ${nodejs}/include "$GYP_FOLDER/include"
            echo 9 > "$GYP_FOLDER/installVersion"
          '';

          nodeBuildPhase = if build then ''
            cat ${writeText "package-lock.json" lockfilePrepared} > "package-lock.json"
            HOME=/tmp npm i ${if buildProduction then "--production" else ""}
          '' else "true";

          preInstallPhases = [ "nodeInstallPhase" ];

          nodeInstallPhase = ''
            npm pack
            tar xfz "${tarball}"
            mv package "$out"

            cd "$out"

            cat ${writeText "package-lock.json" lockfilePrepared} > "package-lock.json"
            HOME=/tmp npm i ${if production then "--production" else ""}

            mkdir -p $out/bin
            # TODO: will possibly break if .bin is literal string (in which case we need to map it to {key: .name, value: .bin})
            cat "$out/package.json" | jq -r --arg out "$out" 'select(.bin != null) | .bin | to_entries | .[] | ["ln", "-s", $out + "/" + .value, $out + "/bin/" + .key] | join(" ")' | sh -ex -

            nuke-refs "$out/package-lock.json"
            for f in $(find -iname package.json); do
              nuke-refs "$f"
            done
          '';

          installPhase = "true"; # add dummy install phase so it won't fail, user can override this
        } attrs);
  in
    makeNode
