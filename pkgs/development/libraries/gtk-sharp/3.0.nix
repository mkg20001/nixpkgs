{ lib, stdenv
, fetchFromGitHub
, fetchpatch
, pkg-config
, meson
, ninja
, mono
, glib
, pango
, gtk3
, GConf ? null
, libglade ? null
, libgtkhtml ? null
, gtkhtml ? null
, libgnomecanvas ? null
, libgnomeui ? null
, libgnomeprint ? null
, libgnomeprintui ? null
, libxml2
, monoDLLFixer
, python3
}:

stdenv.mkDerivation rec {
  pname = "gtk-sharp";
  version = "3.22.1";

  # builder = ./builder.sh;
  src = fetchFromGitHub {
    owner = "GLibSharp";
    repo = "GtkSharp";
    rev = version;
    sha256 = "Vdsriohr+jcfdimSQjYGpTThuuYVqx9Ko6OB5TdLDr8=";
    fetchSubmodules = false;
  };

  mesonFlags = [ "--prefix=${placeholder "out"}" ];
  
  postPatch = ''
    sed "s|install = get_option('install')|install = true|g" -i Source/meson.build
    sed "s|gdk_api_includes|gio_api_includes|g" -i Source/gio/generated/meson.build
  '';

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
    python3
  ];

  buildInputs = [
    mono glib pango gtk3 GConf libglade libgnomecanvas
    libgtkhtml libgnomeui libgnomeprint libgnomeprintui gtkhtml libxml2
  ];

  /* installPhase = ''
    set -x
    export MESON_BUILD_ROOT=$PWD
    cd ..
    export MESON_INSTALL_DESTDIR_PREFIX=$out
    pushd Source
    python3 gacutil_install.py
    popd
  ''; */

  patches = [
    # Fixes MONO_PROFILE_ENTER_LEAVE undeclared when compiling against newer versions of mono.
    # @see https://github.com/mono/gtk-sharp/pull/266
    /* (fetchpatch {
      name = "MONO_PROFILE_ENTER_LEAVE.patch";
      url = "https://github.com/mono/gtk-sharp/commit/401df51bc461de93c1a78b6a7a0d5adc63cf186c.patch";
      sha256 = "0hrkcr5a7wkixnyp60v4d6j3arsb63h54rd30lc5ajfjb3p92kcf";
    }) */
    # @see https://github.com/mono/gtk-sharp/pull/263
    /* (fetchpatch {
      name = "disambiguate_Gtk.Range.patch";
      url = "https://github.com/mono/gtk-sharp/commit/a00552ad68ae349e89e440dca21b86dbd6bccd30.patch";
      sha256 = "1ylplr9g9x7ybsgrydsgr6p3g7w6i46yng1hnl3afgn4vj45rag2";
    }) */
  ];

  dontStrip = true;

  inherit monoDLLFixer;

  passthru = {
    inherit gtk3;
  };

  meta = {
    platforms = lib.platforms.linux;
  };
}
