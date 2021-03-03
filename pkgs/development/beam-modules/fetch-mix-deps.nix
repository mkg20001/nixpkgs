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
  MIX_REBAR = "${rebar}/bin/rebar";
  MIX_REBAR3 = "${rebar3}/bin/rebar3";

  configurePhase = ''
    export HEX_HOME="$TEMPDIR/.hex";
    export MIX_HOME="$TEMPDIR/.mix";
    export MIX_DEPS_PATH="$TEMPDIR/deps";

    # Rebar
    # the api with `mix local.rebar rebar path` makes a copy of the binary
    export REBAR_GLOBAL_CONFIG_DIR="$TMPDIR/rebar3"
    export REBAR_CACHE_DIR="$TMPDIR/rebar3.cache"
  '';

  dontBuild = true;

  installPhase = ''
    mix deps.get --only ${mixEnv}
    find $TEMPDIR/deps -type d -name ".git" -print0 | xargs -0 -I {} rm -rf "{}"
    cp -r --no-preserve=mode,ownership,timestamps $TEMPDIR/deps $out
  '';

  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = sha256;

  impureEnvVars = lib.fetchers.proxyImpureEnvVars;
  inherit meta;
})
