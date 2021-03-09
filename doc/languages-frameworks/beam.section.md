# BEAM Languages (Erlang, Elixir & LFE) {#sec-beam}

## Introduction {#beam-introduction}

In this document and related Nix expressions, we use the term, _BEAM_, to describe the environment. BEAM is the name of the Erlang Virtual Machine and, as far as we're concerned, from a packaging perspective, all languages that run on the BEAM are interchangeable. That which varies, like the build system, is transparent to users of any given BEAM package, so we make no distinction.

## Structure {#beam-structure}

All BEAM-related expressions are available via the top-level `beam` attribute, which includes:

- `interpreters`: a set of compilers running on the BEAM, including multiple Erlang/OTP versions (`beam.interpreters.erlangR19`, etc), Elixir (`beam.interpreters.elixir`) and LFE (Lisp-Flavored-Erlang) (`beam.interpreters.lfe`).

- `packages`: a set of package builders (Mix and rebar3), each compiled with a specific Erlang/OTP version, e.g. `beam.packages.erlangR19`.

The default Erlang compiler, defined by `beam.interpreters.erlang`, is aliased as `erlang`. The default BEAM package set is defined by `beam.packages.erlang` and aliased at the top level as `beamPackages`.

To create a package builder built with a custom Erlang version, use the lambda, `beam.packagesWith`, which accepts an Erlang/OTP derivation and produces a package builder similar to `beam.packages.erlang`.

Many Erlang/OTP distributions available in `beam.interpreters` have versions with ODBC and/or Java enabled or without wx (no observer support). For example, there's `beam.interpreters.erlangR22_odbc_javac`, which corresponds to `beam.interpreters.erlangR22` and `beam.interpreters.erlangR22_nox`, which corresponds to `beam.interpreters.erlangR22`.

## Build Tools {#build-tools}

### Rebar3 {#build-tools-rebar3}

We provide a version of Rebar3, under `rebar3`. We also provide a helper to fetch Rebar3 dependencies from a lockfile under `fetchRebar3Deps`.

### Mix & Erlang.mk {#build-tools-other}

Both Mix and Erlang.mk work exactly as expected. There is a bootstrap process that needs to be run for both, however, which is supported by the `buildMix` and `buildErlangMk` derivations, respectively.

## How to Install BEAM Packages {#how-to-install-beam-packages}

BEAM builders are not registered at the top level, simply because they are not relevant to the vast majority of Nix users. To install any of those builders into your profile, refer to them by their attribute path `beamPackages.rebar3`:

```ShellSession
$ nix-env -f "<nixpkgs>" -iA beamPackages.rebar3
```

## Packaging BEAM Applications {#packaging-beam-applications}

### Erlang Applications {#packaging-erlang-applications}

#### Rebar3 Packages {#rebar3-packages}

The Nix function, `buildRebar3`, defined in `beam.packages.erlang.buildRebar3` and aliased at the top level, can be used to build a derivation that understands how to build a Rebar3 project.

If a package needs to compile native code via Rebar3's port compilation mechanism, add `compilePort = true;` to the derivation.

#### Erlang.mk Packages {#erlang-mk-packages}

Erlang.mk functions similarly to Rebar3, except we use `buildErlangMk` instead of `buildRebar3`.

#### Mix Packages {#mix-packages}

Mix functions similarly to Rebar3, except we use `buildMix` instead of `buildRebar3`.

Alternatively, we can use `buildHex` as a shortcut:

#### buildMix - Elixir Phoenix example

Here is how your default.nix file would look like

```default.nix
with import <nixpkgs-unstable> { };

let
  packages = beam.packagesWith beam.interpreters.erlang;
  src = builtins.fetchGit {
    url = "ssh://git@github.com/your_id/your_repo";
    rev = "replace_with_your_commit";
  };

  nodeDependencies =
    (pkgs.callPackage ./assets/default.nix { }).shell.nodeDependencies;

  name = "your_project";
  version = "0.0.1";

  frontEndFiles = stdenvNoCC.mkDerivation {
    name = "frontend-${name}-${version}";

    nativeBuildInputs = [ nodejs ];

    inherit src;

    buildPhase = ''
      cp -r ./assets $TEMPDIR

      mkdir -p $TEMPDIR/assets/node_modules/.cache
      cp -r ${nodeDependencies}/lib/node_modules $TEMPDIR/assets
      export PATH="${nodeDependencies}/bin:$PATH"

      cd $TEMPDIR/assets
      webpack --config ./webpack.config.js
      cd ..
    '';

    installPhase = ''
      cp -r ./priv/static $out/
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    # nix will complain and tell you the right value to replace this with
    outputHash = lib.fakeSha256;

    impureEnvVars = lib.fetchers.proxyImpureEnvVars;
  };


in packages.buildMix {
  inherit src name version;
  mixEnv = "prod";
  # nix will complain and tell you the right value to replace this with
  depsSha256 = lib.fakeSha256;
  inherit src;
  # if you have build time environment variable add them here
  buildEnvVars = {
    MY_ENV_VAR="my_value";
  };
  preInstall = ''
    mkdir -p ./priv/static
    cp -r ${frontEndFiles} ./priv/static
  '';
}
```

Setup will require the following steps

- Keep in mind that having secrets in the build time environment variables is not recommended. If those are not secrets they can be directly included in the config.
- move your secrets to runtime envionment variables. For more information about this check [runtime.exs docs](https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-runtime-configuration). On a fresh Phoenix build that would mean that both of the `DATABASE_URL` and `SECRET_KEY` need be moved to `runtime.exs`.
- `cd assets` and `node2nix --development` will generate a nix expression containing your frontend dependencies
- commit and push those changes
- you can now `nix-build .`
- When you need to run the release, you will need to at least supply the environment variable RELEASE_TMP that you have write access to.

#### Example of creating a service for an Elixir - Phoenix project

In order to create a service with your release, you could add a `service.nix`
in your project with the following

```Nix
{config, pkgs, lib, ...}:

let
  release = pkgs.callPackage ./default.nix;
  release_name = "app";
  working_directory = "/home/app";
in
{
  systemd.services.${release_name} = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "postgresql.service" ];
    requires = [ "network-online.target" "postgresql.service" ];
    description = "my app";
    environment = {
      # RELEASE_TMP is used to write the state of the
      # VM configuration when the system is running
      # it needs to be a writable directory
      # if you don't set it, it will default to /tmp
      RELEASE_TMP = working_directory;
      MY_VAR = "my_var";
    };
    serviceConfig = {
      Type = "exec";
      DynamicUser = true;
      WorkingDirectory = working_directory;
      # Implied by DynamicUser, but just to emphasize due to RELEASE_TMP
      PrivateTmp = true;
      ExecStart = ''
        ${release}/bin/${release_name} start
      '';
      ExecStop = ''
        ${release}/bin/${release_name} stop
      '';
      ExecReload = ''
        ${release}/bin/${release_name} restart
      '';
      Restart = "on-failure";
      RestartSec = 5;
      StartLimitBurst = 3;
      StartLimitInterval = 10;
    };
    # needed for disksup do have sh available
    path = [ pkgs.bash ];
  };

  environment.systemPackages = [ release ];
}
```

## How to Develop {#how-to-develop}

### Creating a Shell {#creating-a-shell}

Usually, we need to create a `shell.nix` file and do our development inside of the environment specified therein. Just install your version of erlang and other interpreter, and then user your normal build tools. As an example with elixir:

```nix
{ pkgs ? import "<nixpkgs"> {} }:

with pkgs;

let

  elixir = beam.packages.erlangR22.elixir_1_9;

in
mkShell {
  buildInputs = [ elixir ];

  ERL_INCLUDE_PATH="${erlang}/lib/erlang/usr/include";
}
```

#### Elixir - Phoenix project

Here is an example `shell.nix`.

```shell.nix
# latest elixir version are only available on unstable
with import <nixpkgs-unstable> { };

let
  # define packages to install
  basePackages = [
    git
    # replace with beam.packages.erlang.elixir_1_11 if you need
    beam.packages.erlang.elixir
    nodejs-15_x
    postgresql_13
    # only used for frontend dependencies
    # you are free to use yarn2nix as well
    nodePackages.node2nix
    # formatting js file
    nodePackages.prettier
  ];

  inputs = basePackages ++ lib.optional stdenv.isLinux inotify-tools
    ++ lib.optionals stdenv.isDarwin
    (with darwin.apple_sdk.frameworks; [ CoreFoundation CoreServices ]);

  # define shell startup command
  hooks = ''
    # this allows mix to work on the local directory
    mkdir -p $PWD/.nix-mix
    mkdir -p $PWD/.nix-hex
    export MIX_HOME=$PWD/.nix-mix
    export HEX_HOME=$PWD/.nix-mix
    export PATH=$MIX_HOME/bin:$PATH
    export PATH=$HEX_HOME/bin:$PATH
    # TODO: not sure how to make hex available without installing it
    # afterwards.
    mix local.hex --if-missing
    export LANG=en_US.UTF-8
    export ERL_AFLAGS="-kernel shell_history enabled"

    # postges related
    # keep all your db data in a folder inside the project
    export PGDATA="$PWD/db"

    # phoenix related env vars
    export POOL_SIZE=15
    export DB_URL="postgresql://postgres:postgres@localhost:5432/db"
    export PORT=4000
    export MIX_ENV=dev
    # add your project env vars here
    export API_KEY="your_api_key"
  '';

in mkShell {
  buildInputs = inputs;
  shellHook = hooks;
}
```

initializing the project will require the following steps

- create the db directory `initdb ./db` (inside your mix project folder)
- create the postgres user `createuser postgres -ds`
- create the db `createdb db`
- start the postgres instance `pg_ctl -l "$PGDATA/server.log" start`
- add the `/db` folder to your .gitignore
- you can start your phoenix server and get a shell with `iex -S mix phx.server`
