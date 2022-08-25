{ stdenv, fetchgit, flex, bison, python3, autoconf, automake, gnulib, libtool
, gettext, ncurses, libusb-compat-0_1, freetype, qemu, lvm2, unifont, pkg-config
, fetchpatch
, fuse # only needed for grub-mount
, zfs ? null
, efiSupport ? false
, zfsSupport ? true
, xenSupport ? false
, lib
}:

with lib;
let
  pcSystems = {
    i686-linux.target = "i386";
    x86_64-linux.target = "i386";
  };

  efiSystemsBuild = {
    i686-linux.target = "i386";
    x86_64-linux.target = "x86_64";
    aarch64-linux.target = "aarch64";
  };

  # For aarch64, we need to use '--target=aarch64-efi' when building,
  # but '--target=arm64-efi' when installing. Insanity!
  efiSystemsInstall = {
    i686-linux.target = "i386";
    x86_64-linux.target = "x86_64";
    aarch64-linux.target = "arm64";
  };

  canEfi = any (system: stdenv.hostPlatform.system == system) (mapAttrsToList (name: _: name) efiSystemsBuild);
  inPCSystems = any (system: stdenv.hostPlatform.system == system) (mapAttrsToList (name: _: name) pcSystems);

  version = "2.04";

in (

assert efiSupport -> canEfi;
assert zfsSupport -> zfs != null;
assert !(efiSupport && xenSupport);

stdenv.mkDerivation rec {
  pname = "grub";
  inherit version;

  src = fetchgit {
    url = "git://git.savannah.gnu.org/grub.git";
    rev = "${pname}-${version}";
    sha256 = "02gly3xw88pj4zzqjniv1fxa1ilknbq1mdk30bj6qy8n44g90i8w";
  };

  patches = [
    ./fix-bash-completion.patch
    (fetchpatch {
      name = "Add-hidden-menu-entries.patch";
      # https://lists.gnu.org/archive/html/grub-devel/2016-04/msg00089.html
      url = "https://marc.info/?l=grub-devel&m=146193404929072&q=mbox";
      sha256 = "00wa1q5adiass6i0x7p98vynj9vsz1w0gn1g4dgz89v35mpyw2bi";
    })

    # Pull upstream patch to fix linkage against binutils-2.36.
    (fetchpatch {
      name = "binutils-2.36.patch";
      url = "https://git.savannah.gnu.org/cgit/grub.git/patch/?id=b98275138bf4fc250a1c362dfd2c8b1cf2421701";
      sha256 = "001m058bsl2pcb0ii84jfm5ias8zgzabrfy6k2cc9w6w1y51ii82";
    })
    # Properly handle multiple initrd paths in 30_os-prober
    # Remove this patch once a new release is cut
    (fetchpatch {
      name = "Properly-handle-multiple-initrd-paths-in-os-prober.patch";
      url = "https://git.savannah.gnu.org/cgit/grub.git/patch/?id=000b5cd04fd228f9741f5dca0491636bc0b89eb8";
      sha256 = "sha256-Mex3qQ0lW7ZCv7ZI7MSSqbylJXZ5RTbR4Pv1+CJ0ciM=";
    })
  ];

  nativeBuildInputs = [ bison flex python3 pkg-config autoconf automake ];
  buildInputs = [ ncurses libusb-compat-0_1 freetype gettext lvm2 fuse libtool ]
    ++ optional doCheck qemu
    ++ optional zfsSupport zfs;

  hardeningDisable = [ "all" ];

  separateDebugInfo = !xenSupport;

  # Work around a bug in the generated flex lexer (upstream flex bug?)
  NIX_CFLAGS_COMPILE = "-Wno-error";

  preConfigure =
    '' for i in "tests/util/"*.in
       do
         sed -i "$i" -e's|/bin/bash|${stdenv.shell}|g'
       done

       # Apparently, the QEMU executable is no longer called
       # `qemu-system-i386', even on i386.
       #
       # In addition, use `-nodefaults' to avoid errors like:
       #
       #  chardev: opening backend "stdio" failed
       #  qemu: could not open serial device 'stdio': Invalid argument
       #
       # See <http://www.mail-archive.com/qemu-devel@nongnu.org/msg22775.html>.
       sed -i "tests/util/grub-shell.in" \
           -e's/qemu-system-i386/qemu-system-x86_64 -nodefaults/g'

      unset CPP # setting CPP intereferes with dependency calculation

      patchShebangs .

      ./bootstrap --no-git --gnulib-srcdir=${gnulib}

      substituteInPlace ./configure --replace '/usr/share/fonts/unifont' '${unifont}/share/fonts'
    '';

  configureFlags = [ "--enable-grub-mount" ] # dep of os-prober
    ++ optional zfsSupport "--enable-libzfs"
    ++ optionals efiSupport [ "--with-platform=efi" "--target=${efiSystemsBuild.${stdenv.hostPlatform.system}.target}" "--program-prefix=" ]
    ++ optionals xenSupport [ "--with-platform=xen" "--target=${efiSystemsBuild.${stdenv.hostPlatform.system}.target}"];

  # save target that grub is compiled for
  grubTarget = if efiSupport
               then "${efiSystemsInstall.${stdenv.hostPlatform.system}.target}-efi"
               else if inPCSystems
                    then "${pcSystems.${stdenv.hostPlatform.system}.target}-pc"
                    else "";

  doCheck = false;
  enableParallelBuilding = true;

  postInstall = ''
    # Avoid a runtime reference to gcc
    sed -i $out/lib/grub/*/modinfo.sh -e "/grub_target_cppflags=/ s|'.*'|' '|"
  '';

  meta = with lib; {
    description = "GNU GRUB, the Grand Unified Boot Loader (2.x beta)";

    longDescription =
      '' GNU GRUB is a Multiboot boot loader. It was derived from GRUB, GRand
         Unified Bootloader, which was originally designed and implemented by
         Erich Stefan Boleyn.

         Briefly, the boot loader is the first software program that runs when a
         computer starts.  It is responsible for loading and transferring
         control to the operating system kernel software (such as the Hurd or
         the Linux).  The kernel, in turn, initializes the rest of the
         operating system (e.g., GNU).
      '';

    homepage = "https://www.gnu.org/software/grub/";

    license = licenses.gpl3Plus;

    platforms = platforms.gnu ++ platforms.linux;
  };
})
