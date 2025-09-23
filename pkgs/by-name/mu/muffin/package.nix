{
  stdenv,
  lib,
  fetchFromGitHub,
  fetchpatch,
  replaceVars,
  cairo,
  cinnamon-desktop,
  dbus,
  desktop-file-utils,
  egl-wayland,
  glib,
  gobject-introspection,
  graphene,
  gtk3,
  json-glib,
  libcanberra,
  libdrm,
  libgbm,
  libgnomekbd,
  libgudev,
  libinput,
  libstartup_notification,
  libwacom,
  libxcvt,
  libXdamage,
  libxkbcommon,
  libXtst,
  mesa-gl-headers,
  meson,
  ninja,
  pipewire,
  pkg-config,
  python3,
  udev,
  wayland,
  wayland-protocols,
  wayland-scanner,
  wrapGAppsHook3,
  xorgserver,
  xwayland,
  zenity,
}:

stdenv.mkDerivation rec {
  pname = "muffin";
  version = "add0f97604b87cc3e0091224c41677c131e70a61";

  outputs = [
    "out"
    "dev"
    "man"
  ];

  src = fetchFromGitHub {
    owner = "linuxmint";
    repo = "muffin";
    rev = version;
    hash = "sha256-3bGolRUcX/iLHXo0PeXI1qgQfigtR8/MEXxJcD8DfU0=";
  };

  patches = [
    ./keymap.patch
    (replaceVars ./fix-paths.patch {
      inherit zenity;
    })
  ];

  nativeBuildInputs = [
    desktop-file-utils
    meson
    ninja
    pkg-config
    python3
    wrapGAppsHook3
    xorgserver # for cvt command
    gobject-introspection
    wayland-scanner
  ];

  buildInputs = [
    cairo
    cinnamon-desktop
    dbus
    egl-wayland
    glib
    gtk3
    libcanberra
    libdrm
    libgbm
    libgnomekbd
    libgudev
    libinput
    libstartup_notification
    libwacom
    libxcvt
    libXdamage
    libxkbcommon
    pipewire
    udev
    wayland
    wayland-protocols
    xwayland
  ];

  propagatedBuildInputs = [
    # required for pkg-config to detect muffin-clutter
    json-glib
    libXtst
    graphene
    mesa-gl-headers
  ];

  mesonFlags = [
    # Based on Mint's debian/rules.
    "-Degl_device=true"
    "-Dwayland_eglstream=true"
    "-Dxwayland_path=${lib.getExe xwayland}"
  ];

  postPatch = ''
    patchShebangs src/backends/native/gen-default-modes.py
  '';

  meta = with lib; {
    homepage = "https://github.com/linuxmint/muffin";
    description = "Window management library for the Cinnamon desktop (libmuffin) and its sample WM binary (muffin)";
    mainProgram = "muffin";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    teams = [ teams.cinnamon ];
  };
}
