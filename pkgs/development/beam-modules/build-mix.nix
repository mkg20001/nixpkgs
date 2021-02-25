{ stdenv, lib, elixir, erlang, hex, rebar, rebar3, fetchMixDeps, makeWrapper }:

{ name
, version
, src
, nativeBuildInputs ? [ ]
, meta ? { }
, buildEnvVars ? { }
, enableDebugInfo ? false
, depsSha256
, mixEnv ? "prod"
, ...
}@attrs:
let

  mixDeps = fetchMixDeps {
    inherit src name mixEnv version buildEnvVars;
    sha256 = depsSha256;
  };

in
stdenv.mkDerivation (buildEnvVars // {
  name = "${name}-${version}";
  inherit version;

  dontStrip = true;

  inherit src;

  nativeBuildInputs = nativeBuildInputs ++ [ erlang hex elixir makeWrapper ];

  MIX_ENV = mixEnv;
  MIX_DEBUG = if enableDebugInfo then 1 else 0;
  HEX_OFFLINE = 1;
  DEBUG = if enableDebugInfo then 1 else 0; # for Rebar3 compilation

  postUnpack = ''
    export HEX_HOME="$TMPDIR/hex"
    export MIX_HOME="$TMPDIR/mix"
    # compilation of the dependencies will require
    # that the dependency path is writable
    # thus a copy to the TMPDIR is inevitable here
    export MIX_DEPS_PATH="$TMPDIR/deps"

    # Rebar
    # the api with `mix local.rebar rebar path` makes a copy of the binary
    export MIX_REBAR="${rebar}/bin/rebar"
    export MIX_REBAR3="${rebar3}/bin/rebar3"
    export REBAR_GLOBAL_CONFIG_DIR="$TMPDIR/rebar3"
    export REBAR_CACHE_DIR="$TMPDIR/rebar3.cache"

    cp --no-preserve=mode -R "${mixDeps}" "$MIX_DEPS_PATH"

  '' + (attrs.postUnpack or "");

  # TODO enable overriding of preConfigure from the passed attrs
  configurePhase = attrs.configurePhase or ''
    runHook preConfigure

    mix deps.loadpaths

    runHook postConfigure
  '';

  installPhase = attrs.installPhase or ''
    mix do compile --no-deps-check, release --path "$out"
  '';

  postFixup = ''
    wrapProgram $out/bin/${name} \
      --set-default RELEASE_TMP "/tmp"
  '';
  # TODO figure out how to do a Fixed Output Derivation and add the output hash
  # This doesn't play well at the moment with Phoenix projects
  # for example who have frontend dependencies
})
