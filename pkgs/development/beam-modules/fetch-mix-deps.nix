{ stdenvNoCC, lib, elixir, hex, rebar, rebar3, cacert, git }:

{ name
, version
, sha256
, src
, mixEnv ? "prod"
, debug ? false
, buildEnvVars ? { }
, meta ? { }
}:

stdenvNoCC.mkDerivation (buildEnvVars // {
  name = "mix-deps-${name}-${version}";

  nativeBuildInputs = [ elixir hex cacert git ];

  inherit src;

  MIX_ENV = mixEnv;
  MIX_DEBUG = if debug then 1 else 0;
  DEBUG = if debug then 1 else 0; # for rebar3

  configurePhase = ''
    export HEX_HOME="$TEMPDIR/.hex";
    export MIX_HOME="$TEMPDIR/.mix";
    export MIX_DEPS_PATH="$PWD/deps";

    # Rebar
    # the api with `mix local.rebar rebar path` makes a copy of the binary
    export MIX_REBAR="${rebar}/bin/rebar"
    export MIX_REBAR3="${rebar3}/bin/rebar3"
    export REBAR_GLOBAL_CONFIG_DIR="$TMPDIR/rebar3"
    export REBAR_CACHE_DIR="$TMPDIR/rebar3.cache"
  '';

  dontBuild = true;

  installPhase = ''
    mix deps.get --only ${mixEnv}
    # find $PWD/deps -type d -name ".git" -print0 | xargs -0 -I {} rm -rf "{}"

clean_git(){
    git "$@" >&2
}

make_deterministic_repo(){
    local repo="$1"

    # run in sub-shell to not touch current working directory
    (
    cd "$repo"
    # Remove files that contain timestamps or otherwise have non-deterministic
    # properties.
    rm -rf .git/logs/ .git/hooks/ .git/index .git/FETCH_HEAD .git/ORIG_HEAD \
        .git/refs/remotes/origin/HEAD .git/config

    # Remove all remote branches.
    git branch -r | while read -r branch; do
        clean_git branch -rD "$branch"
    done

    # Remove tags not reachable from HEAD. If we're exactly on a tag, don't
    # delete it.
    maybe_tag=$(git tag --points-at HEAD)
    git tag --contains HEAD | while read -r tag; do
        if [ "$tag" != "$maybe_tag" ]; then
            clean_git tag -d "$tag"
        fi
    done

    # Do a full repack. Must run single-threaded, or else we lose determinism.
    clean_git config pack.threads 1
    clean_git repack -A -d -f
    rm -f .git/config

    # Garbage collect unreferenced objects.
    # Note: --keep-largest-pack prevents non-deterministic ordering of packs
    #   listed in .git/objects/info/packs by only using a single pack
    clean_git gc --prune=all --keep-largest-pack
    )
}

  for repogit in $(find $PWD/deps -type d -name ".git"); do
    make_deterministic_repo $(dirname $repogit)
  done

    rm -rf $out
    cp -r --no-preserve=mode,ownership,timestamps $PWD/deps $out
  '';

  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = sha256;

  impureEnvVars = lib.fetchers.proxyImpureEnvVars;
  inherit meta;
})
