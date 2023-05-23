# This module creates a bootable ISO image containing the given NixOS
# configuration.  The derivation for the ISO image will be placed in
# config.system.build.isoImage.

{ config, lib, pkgs, ... }:

with lib;

let
  bootItems = config.isoImage.prependItems ++ [
      { class = "installer"; }
      { class = "nomodeset"; params = "nomodeset"; }
      { class = "copytoram"; params = "copytoram"; }
      { class = "debug";     params = "debug loglevel=7"; }
    ] ++ config.isoImage.appendItems;

  /**
   * Given a list of `options`, concats the result of mapping each options
   * to a menuentry for use in grub.
   *
   *  * defaults: {name, image, params, initrd}
   *  * options: [ option... ]
   *  * option: {name, params, class}
   */
  menuBuilderGrub2 =
  defaults: options: lib.concatStrings
    (
      map
      (option: ''
        menuentry '${defaults.name} ${
        # Name appended to menuentry defaults to params if no specific name given.
        option.name or (optionalString (option ? params) "(${option.params})")
        }' ${optionalString (option ? class) " --class ${option.class}"} {
          linux ${defaults.image} \''${isoboot} ${defaults.params} ${
            option.params or ""
          }
          initrd ${defaults.initrd}
        }
      '')
      options
    )
  ;

  /**
   * Builds the default options.
   */
  buildMenuGrub2 = buildMenuAdditionalParamsGrub2 "";

  /**
   * Given params to add to `params`, build a set of default options.
   * Use this one when creating a variant (e.g. hidpi)
   */
  buildMenuAdditionalParamsGrub2 = additional:
  let
    finalCfg = {
      name = "${config.isoImage.prependToMenuLabel}${config.system.nixos.distroName} ${config.system.nixos.label}${config.isoImage.appendToMenuLabel}";
      params = "init=${config.system.build.toplevel}/init ${additional} ${toString config.boot.kernelParams}";
      image = "/boot/${config.system.boot.loader.kernelFile}";
      initrd = "/boot/initrd";
    };

  in
    menuBuilderGrub2
    finalCfg
    (bootItems)
  ;

  # Timeout in syslinux is in units of 1/10 of a second.
  # null means max timeout (35996, just under 1h in 1/10 seconds)
  # 0 means disable timeout
  syslinuxTimeout = if config.boot.loader.timeout == null then
      35996
    else
      config.boot.loader.timeout * 10;

  # Timeout in grub is in seconds.
  # null means max timeout (infinity)
  # 0 means disable timeout
  grubEfiTimeout = if config.boot.loader.timeout == null then
      -1
    else
      config.boot.loader.timeout;

  # The configuration file for syslinux.

  # Notes on syslinux configuration and UNetbootin compatibility:
  #   * Do not use '/syslinux/syslinux.cfg' as the path for this
  #     configuration. UNetbootin will not parse the file and use it as-is.
  #     This results in a broken configuration if the partition label does
  #     not match the specified config.isoImage.volumeID. For this reason
  #     we're using '/isolinux/isolinux.cfg'.
  #   * Use APPEND instead of adding command-line arguments directly after
  #     the LINUX entries.
  #   * COM32 entries (chainload, reboot, poweroff) are not recognized. They
  #     result in incorrect boot entries.

  refindBinary = if targetArch == "x64" || targetArch == "aa64" then "refind_${targetArch}.efi" else null;

  # Setup instructions for rEFInd.
  refind =
    if refindBinary != null then
      ''
      # Adds rEFInd to the ISO.
      cp -v ${pkgs.refind}/share/refind/${refindBinary} $out/boot/
      ''
    else
      "# No refind for ${targetArch}"
  ;

  grubPkgs = if config.boot.loader.grub.forcei686 then pkgs.pkgsi686Linux else pkgs;

  grubMenuCfg = ''
    #
    # Menu configuration
    #

    # Search using a "marker file"
    search --set=root --file /${config.isoImage.volumeID}

    insmod gfxterm
    insmod png
    set gfxpayload=keep
    set gfxmode=${concatStringsSep "," [
      # GRUB will use the first valid mode listed here.
      # `auto` will sometimes choose the smallest valid mode it detects.
      # So instead we'll list a lot of possibly valid modes :/
      #"3840x2160"
      #"2560x1440"
      "1920x1080"
      "1366x768"
      "1280x720"
      "1024x768"
      "800x600"
      "auto"
    ]}

    # Fonts can be loaded?
    # (This font is assumed to always be provided as a fallback by NixOS)
    if loadfont (\$root)/boot/unicode.pf2; then
      set with_fonts=true
    fi
    if [ "\$textmode" != "true" -a "\$with_fonts" == "true" ]; then
      # Use graphical term, it can be either with background image or a theme.
      # input is "console", while output is "gfxterm".
      # This enables "serial" input and output only when possible.
      # Otherwise the failure mode is to not even enable gfxterm.
      if test "\$with_serial" == "yes"; then
        terminal_output gfxterm serial
        terminal_input  console serial
      else
        terminal_output gfxterm
        terminal_input  console
      fi
    else
      # Sets colors for the non-graphical term.
      set menu_color_normal=cyan/blue
      set menu_color_highlight=white/blue
    fi

    ${ # When there is a theme configured, use it, otherwise use the background image.
    if config.isoImage.grubTheme != null then ''
      # Sets theme.
      set theme=(\$root)/boot/grub-theme/theme.txt
      # Load theme fonts
      $(find ${config.isoImage.grubTheme} -iname '*.pf2' -printf "loadfont (\$root)/boot/grub-theme/%P\n")
    '' else ''
      if background_image (\$root)/boot/efi-background.png; then
        # Black background means transparent background when there
        # is a background image set... This seems undocumented :(
        set color_normal=black/black
        set color_highlight=white/blue
      else
        # Falls back again to proper colors.
        set menu_color_normal=cyan/blue
        set menu_color_highlight=white/blue
      fi
    ''}
  '';

  grubCfg = pkgs.writeText "grub.cfg" ''
    # needed to load config from /boot folder
    insmod configfile
    # those are needed if the ISO gets written to a USB
    insmod part_gpt
    insmod part_msdos

    search --set=root --file /${config.isoImage.volumeID}

    if ! echo; then # if we can't load the echo module, try loading it from the ISO (we're really just testing if we've got all or just a subset of modules)
      set prefix=($root)/boot/grub # see grub dl.c:71
      export prefix
    fi

    # re-try import if anything failed

    # this one fixes a UEFI boot issue (booting in silent mode)
    insmod all_video
    insmod configfile
    # double holds better
    insmod part_gpt
    insmod part_msdos

    source ($root)/boot/grub/grub.cfg
  '';

  # The EFI boot image.
  # Notes about grub:
  #  * Yes, the grubMenuCfg has to be repeated in all submenus. Otherwise you
  #    will get white-on-black console-like text on sub-menus. *sigh*
  grubDir = pkgs.runCommand "grub-directory" {} ''
    mkdir -p $out/boot/grub/

    cp -p "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}" \
      "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}" $out/boot/

    # Add a marker so GRUB can find the filesystem.
    touch $out/${config.isoImage.volumeID}

    # ALWAYS required modules.
    MODULES="fat iso9660 part_gpt part_msdos \
             normal boot linux configfile loopback chain halt \
             efifwsetup efi_gop \
             ls search search_label search_fs_uuid search_fs_file \
             gfxmenu gfxterm gfxterm_background gfxterm_menu test all_video loadenv \
             exfat ext2 ntfs btrfs hfsplus udf \
             videoinfo png \
             echo serial \
            "

    cp ${grubPkgs.grub2_efi}/share/grub/unicode.pf2 $out/boot/

    cat <<EOF > $out/boot/grub/grub.cfg

    insmod all_video

    set with_fonts=false
    set textmode=false
    # If you want to use serial for "terminal_*" commands, you need to set one up:
    #   Example manual configuration:
    #    → serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
    # This uses the defaults, and makes the serial terminal available.
    set with_serial=no
    if serial; then set with_serial=yes ;fi
    export with_serial
    clear
    set timeout=${toString grubEfiTimeout}

    # This message will only be viewable when "gfxterm" is not used.
    echo ""
    echo "Loading graphical boot menu..."
    echo ""
    echo "Press 't' to use the text boot menu on this console..."
    echo ""

    search --set=root --file /${config.isoImage.volumeID}

    ${grubMenuCfg}

    hiddenentry 'Text mode' --hotkey 't' {
      loadfont (\$root)/boot/unicode.pf2
      set textmode=true
      terminal_output gfxterm console
    }
    hiddenentry 'GUI mode' --hotkey 'g' {
      $(find ${config.isoImage.grubTheme} -iname '*.pf2' -printf "loadfont (\$root)/boot/grub-theme/%P\n")
      set textmode=false
      terminal_output gfxterm
    }


    # If the parameter iso_path is set, append the findiso parameter to the kernel
    # line. We need this to allow the nixos iso to be booted from grub directly.
    if [ \''${iso_path} ] ; then
      set isoboot="findiso=\''${iso_path}"
    fi

    #
    # Menu entries
    #

    ${buildMenuGrub2}
    submenu "HiDPI, Quirks and Accessibility" --class hidpi --class submenu {
      ${grubMenuCfg}
      submenu "Suggests resolution @720p" --class hidpi-720p {
        ${grubMenuCfg}
        ${buildMenuAdditionalParamsGrub2 "video=1280x720@60"}
      }
      submenu "Suggests resolution @1080p" --class hidpi-1080p {
        ${grubMenuCfg}
        ${buildMenuAdditionalParamsGrub2 "video=1920x1080@60"}
      }

      # If we boot into a graphical environment where X is autoran
      # and always crashes, it makes the media unusable. Allow the user
      # to disable this.
      submenu "Disable display-manager" --class quirk-disable-displaymanager {
        ${grubMenuCfg}
        ${buildMenuAdditionalParamsGrub2 "systemd.mask=display-manager.service"}
      }

      # Some laptop and convertibles have the panel installed in an
      # inconvenient way, rotated away from the keyboard.
      # Those entries makes it easier to use the installer.
      submenu "" {return}
      submenu "Rotate framebuffer Clockwise" --class rotate-90cw {
        ${grubMenuCfg}
        ${buildMenuAdditionalParamsGrub2 "fbcon=rotate:1"}
      }
      submenu "Rotate framebuffer Upside-Down" --class rotate-180 {
        ${grubMenuCfg}
        ${buildMenuAdditionalParamsGrub2 "fbcon=rotate:2"}
      }
      submenu "Rotate framebuffer Counter-Clockwise" --class rotate-90ccw {
        ${grubMenuCfg}
        ${buildMenuAdditionalParamsGrub2 "fbcon=rotate:3"}
      }

      # As a proof of concept, mainly. (Not sure it has accessibility merits.)
      submenu "" {return}
      submenu "Use black on white" --class accessibility-blakconwhite {
        ${grubMenuCfg}
        ${buildMenuAdditionalParamsGrub2 "vt.default_red=0xFF,0xBC,0x4F,0xB4,0x56,0xBC,0x4F,0x00,0xA1,0xCF,0x84,0xCA,0x8D,0xB4,0x84,0x68 vt.default_grn=0xFF,0x55,0xBA,0xBA,0x4D,0x4D,0xB3,0x00,0xA0,0x8F,0xB3,0xCA,0x88,0x93,0xA4,0x68 vt.default_blu=0xFF,0x58,0x5F,0x58,0xC5,0xBD,0xC5,0x00,0xA8,0xBB,0xAB,0x97,0xBD,0xC7,0xC5,0x68"}
      }

      # Serial access is a must!
      submenu "" {return}
      submenu "Serial console=ttyS0,115200n8" --class serial {
        ${grubMenuCfg}
        ${buildMenuAdditionalParamsGrub2 "console=ttyS0,115200n8"}
      }
    }

    ${lib.optionalString (refindBinary != null) ''
    # GRUB apparently cannot do "chainloader" operations on "CD".
    if [ "\$root" != "cd0" ]; then
      menuentry 'rEFInd' --class refind {
        # Force root to be the FAT partition
        # Otherwise it breaks rEFInd's boot
        search --set=root --no-floppy --fs-uuid 1234-5678
        chainloader (\$root)/boot/${refindBinary}
      }
    fi
    ''}
    menuentry 'Firmware Setup' --class settings {
      fwsetup
      clear
      echo ""
      echo "If you see this message, your EFI system doesn't support this feature."
      echo ""
    }
    menuentry 'Shutdown' --class shutdown {
      halt
    }
    EOF

    ${refind}
  '';

  # Name used by UEFI for architectures.
  targetArch =
    if pkgs.stdenv.isi686 || config.boot.loader.grub.forcei686 then
      "ia32"
    else if pkgs.stdenv.isx86_64 then
      "x64"
    else if pkgs.stdenv.isAarch32 then
      "arm"
    else if pkgs.stdenv.isAarch64 then
      "aa64"
    else
      throw "Unsupported architecture";

  # Syslinux (and isolinux) only supports x86-based architectures.
  canx86BiosBoot = pkgs.stdenv.hostPlatform.isx86;

in

{
  options = {

    isoImage.isoName = mkOption {
      default = "${config.isoImage.isoBaseName}.iso";
      type = lib.types.str;
      description = lib.mdDoc ''
        Name of the generated ISO image file.
      '';
    };

    isoImage.isoBaseName = mkOption {
      default = config.system.nixos.distroId;
      type = lib.types.str;
      description = lib.mdDoc ''
        Prefix of the name of the generated ISO image file.
      '';
    };

    isoImage.compressImage = mkOption {
      default = false;
      type = lib.types.bool;
      description = lib.mdDoc ''
        Whether the ISO image should be compressed using
        {command}`zstd`.
      '';
    };

    isoImage.squashfsCompression = mkOption {
      default = with pkgs.stdenv.hostPlatform; "xz -Xdict-size 100% "
                + lib.optionalString isx86 "-Xbcj x86"
                # Untested but should also reduce size for these platforms
                + lib.optionalString isAarch "-Xbcj arm"
                + lib.optionalString (isPower && is32bit && isBigEndian) "-Xbcj powerpc"
                + lib.optionalString (isSparc) "-Xbcj sparc";
      type = lib.types.str;
      description = lib.mdDoc ''
        Compression settings to use for the squashfs nix store.
      '';
      example = "zstd -Xcompression-level 6";
    };

    isoImage.edition = mkOption {
      default = "";
      type = lib.types.str;
      description = lib.mdDoc ''
        Specifies which edition string to use in the volume ID of the generated
        ISO image.
      '';
    };

    isoImage.volumeID = mkOption {
      # nixos-$EDITION-$RELEASE-$ARCH
      default = "nixos${optionalString (config.isoImage.edition != "") "-${config.isoImage.edition}"}-${config.system.nixos.release}-${pkgs.stdenv.hostPlatform.uname.processor}";
      type = lib.types.str;
      description = lib.mdDoc ''
        Specifies the label or volume ID of the generated ISO image.
        Note that the label is used by stage 1 of the boot process to
        mount the CD, so it should be reasonably distinctive.
      '';
    };

    isoImage.contents = mkOption {
      example = literalExpression ''
        [ { source = pkgs.memtest86 + "/memtest.bin";
            target = "boot/memtest.bin";
          }
        ]
      '';
      description = lib.mdDoc ''
        This option lists files to be copied to fixed locations in the
        generated ISO image.
      '';
    };

    isoImage.storeContents = mkOption {
      example = literalExpression "[ pkgs.stdenv ]";
      description = lib.mdDoc ''
        This option lists additional derivations to be included in the
        Nix store in the generated ISO image.
      '';
    };

    isoImage.includeSystemBuildDependencies = mkOption {
      default = false;
      type = lib.types.bool;
      description = lib.mdDoc ''
        Set this option to include all the needed sources etc in the
        image. It significantly increases image size. Use that when
        you want to be able to keep all the sources needed to build your
        system or when you are going to install the system on a computer
        with slow or non-existent network connection.
      '';
    };

    isoImage.makeBiosBootable = mkOption {
      default = false;
      type = lib.types.bool;
      description = lib.mdDoc ''
        Whether the ISO image should be a BIOS-bootable disk.
      '';
    };

    isoImage.makeEfiBootable = mkOption {
      default = false;
      type = lib.types.bool;
      description = lib.mdDoc ''
        Whether the ISO image should be an EFI-bootable volume.
      '';
    };

    isoImage.makeUsbBootable = mkOption {
      default = false;
      type = lib.types.bool;
      description = lib.mdDoc ''
        Whether the ISO image should be bootable from CD as well as USB.
      '';
    };

    isoImage.splashImage = mkOption {
      default = pkgs.fetchurl { # TODO: update to resized legacy splash
          url = "https://raw.githubusercontent.com/NixOS/nixos-artwork/a9e05d7deb38a8e005a2b52575a3f59a63a4dba0/bootloader/efi-background.png";
          sha256 = "18lfwmp8yq923322nlb9gxrh5qikj1wsk6g5qvdh31c4h5b1538x";
        };
      description = lib.mdDoc ''
        The splash image to use in the EFI bootloader.
      '';
    };

    isoImage.grubTheme = mkOption {
      default = pkgs.nixos-grub2-theme;
      type = types.nullOr (types.either types.path types.package);
      description = lib.mdDoc ''
        The grub2 theme used for UEFI boot.
      '';
    };

    isoImage.syslinuxTheme = mkOption {
      default = ''
        MENU TITLE ${config.system.nixos.distroName}
        MENU RESOLUTION 800 600
        MENU CLEAR
        MENU ROWS 6
        MENU CMDLINEROW -4
        MENU TIMEOUTROW -3
        MENU TABMSGROW  -2
        MENU HELPMSGROW -1
        MENU HELPMSGENDROW -1
        MENU MARGIN 0

        #                                FG:AARRGGBB  BG:AARRGGBB   shadow
        MENU COLOR BORDER       30;44      #00000000    #00000000   none
        MENU COLOR SCREEN       37;40      #FF000000    #00E2E8FF   none
        MENU COLOR TABMSG       31;40      #80000000    #00000000   none
        MENU COLOR TIMEOUT      1;37;40    #FF000000    #00000000   none
        MENU COLOR TIMEOUT_MSG  37;40      #FF000000    #00000000   none
        MENU COLOR CMDMARK      1;36;40    #FF000000    #00000000   none
        MENU COLOR CMDLINE      37;40      #FF000000    #00000000   none
        MENU COLOR TITLE        1;36;44    #00000000    #00000000   none
        MENU COLOR UNSEL        37;44      #FF000000    #00000000   none
        MENU COLOR SEL          7;37;40    #FFFFFFFF    #FF5277C3   std
      '';
      type = types.str;
      description = lib.mdDoc ''
        The syslinux theme used for BIOS boot.
      '';
    };

    isoImage.prependToMenuLabel = mkOption {
      default = "";
      type = types.str;
      example = "Install ";
      description = lib.mdDoc ''
        The string to prepend before the menu label for the NixOS system.
        This will be directly prepended (without whitespace) to the NixOS version
        string, like for example if it is set to `XXX`:

        `XXXNixOS 99.99-pre666`
      '';
    };

    isoImage.appendToMenuLabel = mkOption {
      default = " Installer";
      type = types.str;
      example = " Live System";
      description = lib.mdDoc ''
        The string to append after the menu label for the NixOS system.
        This will be directly appended (without whitespace) to the NixOS version
        string, like for example if it is set to `XXX`:

        `NixOS 99.99-pre666XXX`
      '';
    };

    isoImage.appendItems = mkOption {
      default = [];
      type = types.listOf types.attrs;
      description = "Append menuItems <literalExample>{ class = \"copytoram+persistent\"; params = \"boot.persistence=/dev/disk/by-label/nixos-portable copytoram\"; }</literalExample>";
    };

    isoImage.prependItems = mkOption {
      default = [];
      type = types.listOf types.attrs;
      description = "Prepend menuItems <literalExample>{ class = \"copytoram+persistent\"; params = \"boot.persistence=/dev/disk/by-label/nixos-portable copytoram\"; }</literalExample>";
    };
  };

  # store them in lib so we can mkImageMediaOverride the
  # entire file system layout in installation media (only)
  config.lib.isoFileSystems = {
    "/" = mkImageMediaOverride
      {
        fsType = "tmpfs";
        options = [ "mode=0755" ];
      };

    # Note that /dev/root is a symlink to the actual root device
    # specified on the kernel command line, created in the stage 1
    # init script.
    "/iso" = mkImageMediaOverride
      { device = "/dev/root";
        neededForBoot = true;
        noCheck = true;
      };

    # In stage 1, mount a tmpfs on top of /nix/store (the squashfs
    # image) to make this a live CD.
    "/nix/.ro-store" = mkImageMediaOverride
      { fsType = "squashfs";
        device = "/iso/nix-store.squashfs";
        options = [ "loop" ];
        neededForBoot = true;
      };

    "/nix/.rw-store" = mkImageMediaOverride
      { fsType = "tmpfs";
        options = [ "mode=0755" ];
        neededForBoot = true;
      };

    "/nix/store" = mkImageMediaOverride
      { fsType = "overlay";
        device = "overlay";
        options = [
          "lowerdir=/nix/.ro-store"
          "upperdir=/nix/.rw-store/store"
          "workdir=/nix/.rw-store/work"
        ];
        depends = [
          "/nix/.ro-store"
          "/nix/.rw-store/store"
          "/nix/.rw-store/work"
        ];
      };
  };

  config = {
    assertions = [
      {
        assertion = !(stringLength config.isoImage.volumeID > 32);
        # https://wiki.osdev.org/ISO_9660#The_Primary_Volume_Descriptor
        # Volume Identifier can only be 32 bytes
        message = let
          length = stringLength config.isoImage.volumeID;
          howmany = toString length;
          toomany = toString (length - 32);
        in
        "isoImage.volumeID ${config.isoImage.volumeID} is ${howmany} characters. That is ${toomany} characters longer than the limit of 32.";
      }
    ];

    # Don't build the GRUB menu builder script, since we don't need it
    # here and it causes a cyclic dependency.
    boot.loader.grub.enable = false;

    environment.systemPackages =  [ grubPkgs.grub2 grubPkgs.grub2_efi ]
      ++ optional (config.isoImage.makeBiosBootable && canx86BiosBoot) pkgs.syslinux
    ;

    # In stage 1 of the boot, mount the CD as the root FS by label so
    # that we don't need to know its device.  We pass the label of the
    # root filesystem on the kernel command line, rather than in
    # `fileSystems' below.  This allows CD-to-USB converters such as
    # UNetbootin to rewrite the kernel command line to pass the label or
    # UUID of the USB stick.  It would be nicer to write
    # `root=/dev/disk/by-label/...' here, but UNetbootin doesn't
    # recognise that.
    boot.kernelParams =
      [ "root=LABEL=${config.isoImage.volumeID}"
        "boot.shell_on_fail"
      ];

    fileSystems = config.lib.isoFileSystems;

    boot.initrd.availableKernelModules = [ "squashfs" "iso9660" "uas" "overlay" ];

    boot.initrd.kernelModules = [ "loop" "overlay" ];

    # Closures to be copied to the Nix store on the CD, namely the init
    # script and the top-level system configuration directory.
    isoImage.storeContents =
      [ config.system.build.toplevel ] ++
      optional config.isoImage.includeSystemBuildDependencies
        config.system.build.toplevel.drvPath;

    # Create the squashfs image that contains the Nix store.
    system.build.squashfsStore = pkgs.callPackage ../../../lib/make-squashfs.nix {
      storeContents = config.isoImage.storeContents;
      comp = config.isoImage.squashfsCompression;
    };

    # Individual files to be included on the CD, outside of the Nix
    # store on the CD.
    isoImage.contents =
      [
        { source = config.boot.kernelPackages.kernel + "/" + config.system.boot.loader.kernelFile;
          target = "/boot/" + config.system.boot.loader.kernelFile;
        }
        { source = config.system.build.initialRamdisk + "/" + config.system.boot.loader.initrdFile;
          target = "/boot/" + config.system.boot.loader.initrdFile;
        }
        { source = config.system.build.squashfsStore;
          target = "/nix-store.squashfs";
        }
        { source = config.isoImage.splashImage;
          target = "/boot/grub/background.png";
        }
        { source = pkgs.writeText "version" config.system.nixos.label;
          target = "/version.txt";
        }
        {
          source = grubDir;
          target = "/";
        }
        {
          source = pkgs.writeText config.isoImage.volumeID "STUB TO FIND IMAGE";
          target = "/${config.isoImage.volumeID}";
        }
        { source = config.isoImage.splashImage;
          target = "/EFI/boot/efi-background.png";
        }
      ] ++ optionals (config.boot.loader.grub.memtest86.enable && config.isoImage.makeBiosBootable && canx86BiosBoot) [
        { source = "${pkgs.memtest86plus}/memtest.bin";
          target = "/boot/memtest.bin";
        }
      ] ++ optionals (config.isoImage.grubTheme != null) [
        { source = config.isoImage.grubTheme;
          target = "/boot/grub/grub-theme";
        }
      ];

    boot.loader.timeout = 10;

    # Create the ISO image.
    system.build.isoImage = pkgs.callPackage ../../../lib/make-iso9660-image.nix ({
      inherit (config.isoImage) isoName compressImage volumeID contents;

      grubDir = grubDir;
      grubCfg = grubCfg;

      mbrBootable = canx86BiosBoot;
    } // optionalAttrs (config.isoImage.makeUsbBootable && canx86BiosBoot) {
      usbBootable = true;
    } // optionalAttrs config.isoImage.makeEfiBootable {
      efiBootable = true;
    });

    boot.postBootCommands =
      ''
        # After booting, register the contents of the Nix store on the
        # CD in the Nix database in the tmpfs.
        ${config.nix.package.out}/bin/nix-store --load-db < /nix/store/nix-path-registration

        # nixos-rebuild also requires a "system" profile and an
        # /etc/NIXOS tag.
        touch /etc/NIXOS
        ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      '';

    # Add vfat support to the initrd to enable people to copy the
    # contents of the CD to a bootable USB stick.
    boot.initrd.supportedFilesystems = [ "vfat" ];

  };

}
