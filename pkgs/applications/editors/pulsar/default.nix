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
, makeDesktopItem
, copyDesktopItems
, makeWrapper
}:

let
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

  # Hunspell
  hunspellDirs = builtins.map (lang: "${hunspellDicts.${lang}}/share/hunspell") languages;
  hunspellTargetDirs = "$out/opt/Pulsar/resources/app.asar.unpacked/node_modules/spellchecker/vendor/hunspell_dictionaries";
  hunspellCopyCommands = lib.concatMapStringsSep "\n" (lang: "cp -r ${lang}/* ${hunspellTargetDirs};") hunspellDirs;

  desktopItem = makeDesktopItem {
    name = "Pulsar";
    desktopName = "Pulsar";
    exec = "pulsar";
    icon = "pulsar";
    comment = "A Community-led Hyper-Hackable Text Editor";
    genericName = "Text Editor";
    categories = [ "Development" "TextEditor" "Utility" ];
    mimeTypes = [ "text/plain" ];
  };
in
stdenv.mkDerivation rec {
  inherit pname version;

  src = with sourcesPath; fetchzip {
    url = "https://github.com/pulsar-edit/pulsar/releases/download/v${version}/${tarname}";
    inherit hash;
  };

  patches = [
    ./001-patch-wrapper.patch
  ];

  patchFlags = [ ];

  nativeBuildInputs = [
    wrapGAppsHook
    copyDesktopItems
  ];

  buildInputs = [
    gtk3
    xorg.libxkbfile
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
  '' + lib.optionalString useHunspell ''
    # On all platforms, we must inject our dictionnaries
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

    # We have patched the original wrapper, but now it needs the "PULSAR_PATH" env var
    mkdir -p $out/bin
    wrapProgram $opt/resources/pulsar.sh \
      --prefix "PULSAR_PATH" : "$opt/pulsar"
    ln -s $opt/resources/pulsar.sh $out/bin/pulsar

    # Copy the icons
    mkdir -p $out/share/icons/hicolor/scalable/apps $out/share/icons/hicolor/1024x1024/apps
    cp $opt/resources/pulsar.svg $out/share/icons/hicolor/scalable/apps/pulsar.svg
    cp $opt/resources/pulsar.png $out/share/icons/hicolor/1024x1024/apps/pulsar.png
  '';

  desktopItems = [ desktopItem ];

  meta = with lib; {
    description = "A Community-led Hyper-Hackable Text Editor";
    longDescription = ''
      A Community-led Hyper-Hackable Text Editor, Forked from Atom, built on Electron.
      Designed to be deeply customizable, but still approachable using the default configuration.
    '';
    homepage = "https://github.com/pulsar-edit/pulsar";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = with maintainers; [ colamaroro ];
  };
}
