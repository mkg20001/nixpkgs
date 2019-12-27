#!/bin/bash

set -euo pipefail

git fetch origin

_reb() {
  git rebase -i $1 || bash
}


for branch in $(cat rebase_branches); do
  git checkout $branch
  _reb origin/master
  git checkout mkg-patch
  _reb $branch
done
