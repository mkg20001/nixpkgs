{ flutter
, lib
, clang10Stdenv
, cmake
, ninja
, pkg-config
, wrapGAppsHook
, autoPatchelfHook
, util-linux
, libselinux
, libsepol
, libthai
, libdatrie
, libxkbcommon
, at-spi2-core
, libsecret
, jsoncpp
, xorg
, dbus
, gtk3
, glib
, pcre
, epoxy
, stdenvNoCC
, cacert
, git
, dart
, pkgs
}:

/*

this needs to be fixed:

Perhaps you should add the directory containing `mount.pc'⡿
to the PKG_CONFIG_PATH environment variable               ⢿
Package 'mount', required by 'gio-2.0', not found         ⣻

[        ] Perhaps you should add the directory containing `atspi-2.pc'
[        ] to the PKG_CONFIG_PATH environment variable
[        ] Package 'atspi-2', required by 'atk-bridge-2.0', not found

*/

args:
let
  placeholder = "##FLUTTER_SRC_ROOT_PLACEHOLDER_MARKER##";
  fetchAttrs = [ "src" "sourceRoot" "setSourceRoot" "unpackPhase" "patches" ];
  getAttrsOrNull = names: attrs: lib.genAttrs names (name: if attrs ? ${name} then attrs.${name} else null);
  flutterDeps = with pkgs; [
    # flutter deps
    flutter.unwrapped
    bash
    curl
    flutter.dart
    git
    unzip
    which
    xz
  ];
  bla =
(self: clang10Stdenv.mkDerivation (lib.recursiveUpdate args {
  # FIXME: unstable hash, fod contains store references (that's why base64) - but I want to make it work first
  # FIXME: pubspec lock should be explict
  # FIXME: libepoxy hack (maybe autopatchelf hook can go then too)
  # absolutely no mac support for now
  deps = stdenvNoCC.mkDerivation (lib.recursiveUpdate (getAttrsOrNull fetchAttrs args) {
    name = "${self.name}-deps.tar.gz";

    nativeBuildInputs = flutterDeps;

    installPhase = ''
      TMP=$(mktemp -d)
      export HOME="$TMP"
      export PUB_CACHE=''${PUB_CACHE:-"$HOME/.pub-cache"}
      export ANDROID_EMULATOR_USE_SYSTEM_LIBS=1

      flutter config --no-analytics >/dev/null 2>/dev/null # mute first-run
      flutter config --enable-linux-desktop
      flutter packages get
      flutter build linux || true # so it downloads tools

      # RES=$(mktemp -d)
      # RES="$out"
      RES="$TMP"

      mkdir -p "$RES/f"

      # mv "$TMP/.pub-cache" "$RES"
      # so we can use lock, diff yaml
      cp "pubspec.yaml" "$RES"
      cp "pubspec.lock" "$RES"
      mv -v .dart_tool .flutter-plugins .flutter-plugins-dependencies .packages "$RES/f"

      find "$RES" -type f -exec sed -i \
        -e s,$TMP,${placeholder},g \
        {} +

      # tar it so nix doesn't do strange things with it (like delete it)
      tar czC "$RES" . | base64 > "$out"
      # ls "$out"
      # find -type f nuke-refs
    '';

    GIT_SSL_CAINFO = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND" "NIX_GIT_SSL_CAINFO" "SOCKS_SERVER"
    ];

    # unnecesarry
    dontFixup = true;

    outputHashAlgo = if self ? vendorHash then null else "sha256";
    # outputHashMode = "recursive";
    outputHash = if self ? vendorHash then
      self.vendorHash
    else if self ? vendorSha256 then
      self.vendorSha256
    else
      lib.fakeSha256;

  });

  nativeBuildInputs = with pkgs; flutterDeps ++ [
    # flutter dev tools
    cmake
    ninja
    pkg-config
    wrapGAppsHook
    # flutter likes dynamic linking
    autoPatchelfHook
  ];

  buildInputs = [
    # cmake deps
    gtk3
    glib
    pcre
    util-linux
    # also required by cmake, not sure if really needed or dep of all packages
    libselinux
    libsepol
    libthai
    libdatrie
    xorg.libXdmcp
    xorg.libXtst
    libxkbcommon
    dbus
    at-spi2-core
    libsecret
    jsoncpp
    # build deps
    xorg.libX11
    # directly required by build
    epoxy
  ];

  # TODO: do we need this?
  NIX_LDFLAGS = "-rpath ${lib.makeLibraryPath self.buildInputs}";
  NIX_CFLAGS_COMPILE = "-I${xorg.libX11}/include";
  LD_LIBRARY_PATH = lib.makeLibraryPath self.buildInputs;

  configurePhase = ''
    runHook preConfigure

    cp pubspec.yaml bla
    cat pubspec.yaml

    # we get this from $depsFolder, but we might need it again once deps are fetched properly
    # flutter config --no-analytics >/dev/null 2>/dev/null # mute first-run
    # flutter config --enable-linux-desktop

    depsFolder=$(mktemp -d)
    cat "$deps" | base64 -d | tar xzC "$depsFolder"
    find "$depsFolder" -type f -exec sed -i \
      -e s,${placeholder},$depsFolder,g \
      {} +

    if [ -e pubspec.lock ]; then
      diff -u pubspec.lock $depsFolder/pubspec.lock
    else
      cp -v "$depsFolder/pubspec.lock" .
    fi
    diff -u pubspec.yaml $depsFolder/pubspec.yaml
    mv -v $(find $depsFolder/f -type f) .
    export HOME=$depsFolder
    export PUB_CACHE=''${PUB_CACHE:-"$HOME/.pub-cache"}
    export ANDROID_EMULATOR_USE_SYSTEM_LIBS=1
    # mv "$depsFolder/.pub-cache" "$HOME"

    autoPatchelf -- "$depsFolder"

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    cat pubspec.yaml bla
    cp bla pubspec.yaml
    pwd

    flutter packages get --offline -v
    flutter build linux --release -v ${/*optionalStrings (target != null) (escapeShellArgs [ "-t" target ])*/""}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    built=build/linux/*/release/bundle

    mkdir -p $out/bin
    mv $built $out/app

    for f in $built/data/flutter_assets/assets/*.desktop; do
      install -D $f $out/share/applications/$(basename $f)
    done
    for f in $(find $out/app -maxdepth 1 -type f); do
      ln -s $f $out/bin/$(basename $f)
    done

    # remove stuff like /build/source/packages/ubuntu_desktop_installer/linux/flutter/ephemeral
    for f in $(find $out/app/lib -type f); do
      if patchelf --print-rpath $f | grep /build; then
        newrp=$(patchelf --print-rpath $f | sed -r "s|/build.*ephemeral:||g")
        patchelf --set-rpath "$newrp" "$f"
      fi
    done

    runHook postInstall
  '';
})) bla;
in
  bla
