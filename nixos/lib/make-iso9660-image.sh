source $stdenv/setup

sources_=($sources)
targets_=($targets)

objects=($objects)
symlinks=($symlinks)


# Remove the initial slash from a path, since genisofs likes it that way.
stripSlash() {
    res="$1"
    if test "${res:0:1}" = /; then res=${res:1}; fi
}

# Escape potential equal signs (=) with backslash (\=)
escapeEquals() {
    echo "$1" | sed -e 's/\\/\\\\/g' -e 's/=/\\=/g'
}

# Queues an file/directory to be placed on the ISO.
# An entry consists of a local source path (2) and
# a destination path on the ISO (1).
addPath() {
    target="$1"
    source="$2"
    echo "$(escapeEquals "$target")=$(escapeEquals "$source")" >> pathlist
}

stripSlash "$bootImage"; bootImage="$res"

TMP=$(mktemp -d)

if test -n "$mbrBootable"; then
  "$grubMbr/bin/grub-mkstandalone" \
      --format=i386-pc \
      --output="$TMP/core.img" \
      --install-modules="linux normal iso9660 biosdisk memdisk search tar ls" \
      --modules="linux normal iso9660 biosdisk search" \
      --locales="" \
      --fonts="" \
      "boot/grub/grub.cfg=$grubCfg"

  cat \
      "$grubMbr/lib/grub/i386-pc/cdboot.img" \
      "$TMP/core.img" \
  > "$TMP/bios.img"

  addPath /boot/grub/bios.img "$TMP/bios.img"

  isoBootFlags=" -eltorito-boot
                    boot/grub/bios.img
                    -no-emul-boot
                    -boot-load-size 4
                    -boot-info-table
                    --eltorito-catalog boot/grub/boot.cat
                --grub2-boot-info
                --grub2-mbr $grubMbr/lib/grub/i386-pc/boot_hybrid.img"
fi

if test -n "$efiBootable"; then
  "$grubEfi/bin/grub-mkstandalone" \
      --format=x86_64-efi \
      --output="$TMP/bootx64.efi" \
      --locales="" \
      --fonts="" \
      "boot/grub/grub.cfg=$grubCfg"

  (pushd "$TMP" && \
      dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
      mkfs.vfat efiboot.img && \
      mmd -i efiboot.img efi efi/boot && \
      mcopy -i efiboot.img ./bootx64.efi ::efi/boot/ \
   && popd)

   addPath /EFI/efiboot.img "$TMP/efiboot.img"

   efiBootFlags=" -eltorito-alt-boot
                      -e EFI/efiboot.img
                      -no-emul-boot
                  -append_partition 2 0xef $TMP/efiboot.img"
fi

# if test -n "$bootable"; then
#
#     # The -boot-info-table option modifies the $bootImage file, so
#     # find it in `contents' and make a copy of it (since the original
#     # is read-only in the Nix store...).
#     for ((i = 0; i < ${#targets_[@]}; i++)); do
#         stripSlash "${targets_[$i]}"
#         if test "$res" = "$bootImage"; then
#             echo "copying the boot image ${sources_[$i]}"
#             cp "${sources_[$i]}" boot.img
#             chmod u+w boot.img
#             sources_[$i]=boot.img
#         fi
#     done
#
#     isoBootFlags="-eltorito-boot ${bootImage}
#                   -eltorito-catalog .boot.cat
#                   -no-emul-boot -boot-load-size 4 -boot-info-table
#                   --sort-weight 1 /isolinux" # Make sure isolinux is near the beginning of the ISO
# fi
#
# if test -n "$usbBootable"; then
#     usbBootFlags="-isohybrid-mbr ${isohybridMbrImage}"
# fi
#
# if test -n "$efiBootable"; then
#     efiBootFlags="-eltorito-alt-boot
#                   -e $efiBootImage
#                   -no-emul-boot
#                   -isohybrid-gpt-basdat"
# fi

touch pathlist


# Add the individual files.
for ((i = 0; i < ${#targets_[@]}; i++)); do
    stripSlash "${targets_[$i]}"
    addPath "$res" "${sources_[$i]}"
done


# Add the closures of the top-level store objects.
for i in $(< $closureInfo/store-paths); do
    addPath "${i:1}" "$i"
done


# Also include a manifest of the closures in a format suitable for
# nix-store --load-db.
if [[ ${#objects[*]} != 0 ]]; then
    cp $closureInfo/registration nix-path-registration
    addPath "nix-path-registration" "nix-path-registration"
fi


# Add symlinks to the top-level store objects.
for ((n = 0; n < ${#objects[*]}; n++)); do
    object=${objects[$n]}
    symlink=${symlinks[$n]}
    if test "$symlink" != "none"; then
        mkdir -p $(dirname ./$symlink)
        ln -s $object ./$symlink
        addPath "$symlink" "./$symlink"
    fi
done

mkdir -p $out/iso

xorriso="xorriso
 -as mkisofs
 -iso-level 3
 -full-iso9660-filenames

 -volid ${volumeID}
 -appid nixos
 -publisher nixos

 -graft-points
 ${isoBootFlags}
 ${usbBootFlags}
 ${efiBootFlags}
 -r
 -path-list pathlist
 --sort-weight 0 /
"


$xorriso -output $out/iso/$isoName

#if test -n "$usbBootable"; then
#    echo "Making image hybrid..."
#    if test -n "$efiBootable"; then
#        isohybrid --uefi $out/iso/$isoName
#    else
#        isohybrid $out/iso/$isoName
#    fi
#fi

if test -n "$compressImage"; then
    echo "Compressing image..."
    bzip2 $out/iso/$isoName
fi

mkdir -p $out/nix-support
echo $system > $out/nix-support/system
echo "file iso $out/iso/$isoName" >> $out/nix-support/hydra-build-products
