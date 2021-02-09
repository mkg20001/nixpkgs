{ stdenv, lib, elixir, erlang, hex, rebar, rebar3, fetchMixDeps }:

{ name, version, src, nativeBuildInputs ? [ ], meta ? { }
, enableDebugInfo ? false, depsSha256, mixEnv ? "prod", ... }@attrs:

let

  shell = drv:
    stdenv.mkDerivation {
      name = "interactive-shell-${drv.name}";
      buildInputs = [ drv ];
    };

  mixDeps = fetchMixDeps {
    inherit src name mixEnv version;
    sha256 = depsSha256;
  };

  pkg = self:
    stdenv.mkDerivation (attrs // {
      name = "${name}-${version}";
      inherit version;

      dontStrip = true;

      inherit src;

      nativeBuildInputs = nativeBuildInputs ++ [ erlang hex elixir ];

      MIX_ENV = mixEnv;
      MIX_DEBUG = if enableDebugInfo then 1 else 0;
      HEX_OFFLINE = 1;
      DEBUG = if enableDebugInfo then 1 else 0; # for Rebar3 compilation

      postUnpack = ''
        export HEX_HOME="$TMPDIR/hex"
        export MIX_HOME="$TMPDIR/mix"
        export MIX_DEPS_PATH="$TMPDIR/deps"

        # Rebar
        mix local.rebar rebar "${rebar}/bin/rebar"
        mix local.rebar rebar3 "${rebar3}/bin/rebar3"
        export REBAR_GLOBAL_CONFIG_DIR="$TMPDIR/rebar3"
        export REBAR_CACHE_DIR="$TMPDIR/rebar3.cache"

        cp --no-preserve=mode -R "${mixDeps}" "$MIX_DEPS_PATH"
      '' + (attrs.postUnpack or "");

      configurePhase = attrs.configurePhase or ''
        runHook preConfigure

        mix deps.loadpaths
        runHook postConfigure
      '';

      buildPhase = attrs.buildPhase or ''
        runHook preBuild
        mix do compile --no-deps-check, release --path "$out"
        runHook postBuild
      '';

      dontInstall = true;

      passthru = {
        packageName = name;
        env = shell self;
      };
    });
in pkg lib.fix
