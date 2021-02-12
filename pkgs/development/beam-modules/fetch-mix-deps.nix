{ stdenvNoCC, lib, elixir, hex, rebar, rebar3, cacert, git }:

{ name, version, sha256, preConfigure, src, mixEnv ? "prod", debug ? false
, meta ? { } }:

stdenvNoCC.mkDerivation ({
  name = "mix-deps-${name}-${version}";

  nativeBuildInputs = [ elixir hex cacert git ];

  inherit src preConfigure;

  MIX_ENV = mixEnv;
  MIX_DEBUG = if debug then 1 else 0;
  DEBUG = if debug then 1 else 0; # for rebar3

  configurePhase = ''
    runHook preConfigure
    export HEX_HOME="$TEMPDIR/.hex";
    export MIX_HOME="$TEMPDIR/.mix";
    export MIX_DEPS_PATH="$out";

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
  '';

  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = sha256;

  impureEnvVars = lib.fetchers.proxyImpureEnvVars;
  inherit meta;
})
