#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl common-updater-scripts gnused nix coreutils jq

set -euo pipefail

cd $(dirname "$0")

latestVersion="$(curl -s "https://api.github.com/repos/pulsar-edit/pulsar/releases" | jq -r ".[] | select(.prerelease == false) | .tag_name" | head -n 1 | sed "s|v||g")"
currentVersion=$(nix-instantiate --eval -E "with import ../../../.. {}; pulsar.version" | tr -d '"')

if [[ "$currentVersion" == "$latestVersion" ]]; then
  echo "pulsar is up-to-date: $currentVersion"
  exit 0
fi

update-source-version pulsar 0 sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
update-source-version pulsar "$latestVersion"
