{ lib
, stdenv
, git
, runtimeShell
, fetchzip
, wrapGAppsHook
, glib
, gtk3
, atomEnv
, xorg
, libxkbcommon
, hunspell
, hunspellDicts
, useHunspell ? true
, languages ? [ "en_US" ]
, nodePackages # We need ASAR to unpack the app.asar file and patch paths
, python3 # Cursed patch to allow asar unpacking, as the builtin in the unpacked asar isn't there
, makeDesktopItem
}:

let
  owner = "pulsar-edit";
  pname = "Pulsar";
  version = "1.103.0";

  sourcesPath = {
    x86_64-linux = {
      tarname = "Linux.${pname}-${version}.tar.gz";
      hash = "sha256-O+mekV2h3mxRPYpIrpoPHQyRDuXgl+En8n8u2yBG8TQ=";
    };
    aarch64-linux = {
      tarname = "ARM.Linux.${pname}-${version}-arm64.tar.gz";
      hash = "sha256-gajIHUJrjCogcJjJVSKz85/x9inuS9rEMYlLqcolUqg=";
    };
  }.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  additionalLibs = lib.makeLibraryPath [
    xorg.libxshmfence
    libxkbcommon
    xorg.libxkbfile
  ];
  newLibpath = "${atomEnv.libPath}:${additionalLibs}";

  # Hunspell for x86_64-linux
  buildLocalePath = path: "searchPaths.push('${path}');";
  localeDerivations = builtins.map (lang: hunspellDicts.${lang}) languages;
  localePatchs = lib.concatMapStringsSep "" buildLocalePath localeDerivations;

  # Hunspell for aarch64-linux
  hunspellDirs = builtins.map (lang: "${hunspellDicts.${lang}}/share/hunspell") languages;
  hunspellTargetDirs = "$out/opt/Pulsar/resources/app.asar.unpacked/node_modules/spellchecker/vendor/hunspell_dictionaries";
  hunspellCopyCommands = lib.concatMapStringsSep "\n" (lang: "cp -r ${lang}/* ${hunspellTargetDirs};") hunspellDirs;
in
stdenv.mkDerivation rec {
  inherit pname version;

  src = with sourcesPath; fetchzip {
    url = "https://github.com/${owner}/${pname}/releases/download/v${version}/${tarname}";
    inherit hash;
  };

  nativeBuildInputs = [
    wrapGAppsHook # Fix error: GLib-GIO-ERROR **: No GSettings schemas are installed on the system
  ] ++ lib.optional useHunspell [
    nodePackages.asar # We need ASAR to unpack the app.asar file and patch paths
  ];

  buildInputs = [
    gtk3 # Fix error: GLib-GIO-ERROR **: Settings schema 'org.gtk.Settings.FileChooser' is not installed
    xorg.libxkbfile # Fix error on electron: libxkbfile.so.1: cannot open shared object file: No such file or directory
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/Pulsar
    mv * $out/opt/Pulsar

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      # needed for gio executable to be able to delete files
      --prefix "PATH" : "${lib.makeBinPath [ glib ]}"
    )
  '' + lib.optionalString (useHunspell && stdenv.hostPlatform.system == "x86_64-linux") ''
    opt=$out/opt/Pulsar
    # We need to patch the already existing app.asar.unpacked, and add python3
    # to resources/app.asar.unpacked/node_modules/tree-sitter-bash/build/node_gyp_bins/python3
    rm $opt/resources/app.asar.unpacked/node_modules/tree-sitter-bash/build/node_gyp_bins/python3
    ln -s ${python3}/bin/python3 $opt/resources/app.asar.unpacked/node_modules/tree-sitter-bash/build/node_gyp_bins/python3

    # We need to extract the app.asar file
    asar extract $opt/resources/app.asar ./app

    # Remove lines 114 to 116 (inclusive) and replace with ''${localePaths}
    sed -i '114,116d' ./app/node_modules/spell-check/lib/locale-checker.js
    echo 'sed -i "114i ${localePatchs}" ./app/node_modules/spell-check/lib/locale-checker.js'
    sed -i "114i ${localePatchs}" ./app/node_modules/spell-check/lib/locale-checker.js
    # Rebuild app.asar and clean up
    asar pack ./app $opt/resources/app.asar
    rm -rf ./app
  '' + lib.optionalString (useHunspell && stdenv.hostPlatform.system == "aarch64-linux") ''
    # On aarch64, we must inject our dictionnaries
    ${hunspellCopyCommands}
  '';

  postFixup = ''
    opt=$out/opt/Pulsar
    # Patch the prebuilt binaries
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      --set-rpath "${newLibpath}:$opt" \
      --add-needed libffmpeg.so \
      --add-needed libxshmfence.so.1 \
      --add-needed libxkbcommon.so.0 \
      --add-needed libxkbfile.so.1 \
      --add-needed libsecret-1.so.0 \
      $opt/pulsar
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      --set-rpath "${newLibpath}" \
      $opt/resources/app/ppm/bin/node
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      $opt/resources/app.asar.unpacked/node_modules/symbols-view/vendor/ctags-linux

  '' + lib.optionalString (stdenv.hostPlatform.system == "x86_64-linux") ''
    # Replace the bundled git with the one from nixpkgs
    dugite=$opt/resources/app.asar.unpacked/node_modules/dugite
    rm -f $dugite/git/bin/git
    ln -s ${git}/bin/git $dugite/git/bin/git
    rm -f $dugite/git/libexec/git-core/git
    ln -s ${git}/bin/git $dugite/git/libexec/git-core/git
  '' + ''
    # Patch the bundled node executables
    find $opt -name "*.node" -exec patchelf --set-rpath "${newLibpath}:$opt" {} \;

    # Create a wrapper script for the executable
    mkdir -p $out/bin
    cat > $out/bin/${pname} <<EOF
    #!${runtimeShell}
    nohup $opt/pulsar --no-sandbox "\$@" > /dev/null 2>&1 &
    EOF
    chmod +x $out/bin/${pname}

    # Place the desktop icons and file
    mkdir -p $out/share/icons/hicolor/scalable/apps $out/share/icons/hicolor/1024x1024/apps
    cp $opt/resources/pulsar.svg $out/share/icons/hicolor/scalable/apps/pulsar.svg
    cp $opt/resources/pulsar.png $out/share/icons/hicolor/1024x1024/apps/pulsar.png

    mkdir -p $out/share/applications
    ln -s ${desktopFile}/share/applications/* $out/share/applications
  '';

  desktopFile = makeDesktopItem {
    name = "Pulsar";
    desktopName = "Pulsar";
    exec = pname;
    icon = "pulsar";
    comment = meta.description;
    genericName = "Text Editor";
    categories = [ "Development" "TextEditor" "Utility" ];
    mimeTypes = [ "text/plain" ];
  };

  meta = with lib; {
    description = "A Community-led Hyper-Hackable Text Editor";
    longDescription = ''
      A Community-led Hyper-Hackable Text Editor, Forked from Atom, built on Electron.
      Designed to be deeply customizable, but still approachable using the default configuration.
    '';
    homepage = "https://github.com/pulsar-edit/pulsar";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.mit;
    platforms = platforms.x86_64 ++ platforms.aarch64;
    maintainers = with maintainers; [ colamaroro ];
  };
}
