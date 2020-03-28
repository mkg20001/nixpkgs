{ stdenv, closureInfo, xorriso, mtools, grub2_efi, grub2_full, dosfstools, grubDir

, # The file name of the resulting ISO image.
  isoName ? "cd.iso"

, # The files and directories to be placed in the ISO file system.
  # This is a list of attribute sets {source, target} where `source'
  # is the file system object (regular file or directory) to be
  # grafted in the file system at path `target'.
  contents

, # In addition to `contents', the closure of the store paths listed
  # in `storeContents' are also placed in the Nix store of the CD.
  # This is a list of attribute sets {object, symlink} where `object'
  # is a store path whose closure will be copied, and `symlink' is a
  # symlink to `object' that will be added to the CD.
  storeContents ? []

, # Whether this should be an El-Torito bootable CD.
  mbrBootable ? false

, # Whether this should be an efi-bootable El-Torito CD.
  efiBootable ? false

, # Whether this should be an hybrid CD (bootable from USB as well as CD).
  usbBootable ? false

, # Whether to compress the resulting ISO image with bzip2.
  compressImage ? false

, # The volume ID.
  volumeID ? ""
}:

stdenv.mkDerivation {
  name = isoName;
  builder = ./make-iso9660-image.sh;
  buildInputs = [
    grub2_full
    grub2_efi
    xorriso
    mtools # mmd
    dosfstools # mkfs.vfat
  ];

  grubEfi = grub2_efi;
  grubMbr = grub2_full;

  inherit
    isoName volumeID
    mbrBootable efiBootable usbBootable
    grubDir;

  grubCfg = "${grubDir}/boot/grub.cfg";

  # !!! should use XML.
  sources = map (x: x.source) contents;
  targets = map (x: x.target) contents;

  # !!! should use XML.
  objects = map (x: x.object) storeContents;
  symlinks = map (x: x.symlink) storeContents;

  # For obtaining the closure of `storeContents'.
  closureInfo = closureInfo { rootPaths = map (x: x.object) storeContents; };
}
