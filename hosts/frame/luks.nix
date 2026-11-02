# LUKS2 -> LVM frame-vg -> LV root (NixOS.md 2.3). Real host only.
# Unlocking with the YubiKey (FIDO2) after
#   sudo systemd-cryptenroll --fido2-device=auto /dev/disk/by-partlabel/cryptroot
# the passphrase stays as second key slot.
{...}: {
  boot.initrd.luks.devices."cryptroot" = {
    # GPT partition name set at partitioning (sgdisk -c 2:cryptroot); works
    # on nvme0n1 (frame) and vda (libvirt rehearsal) without UUID edits
    device = "/dev/disk/by-partlabel/cryptroot";
    allowDiscards = true;
    crypttabExtraOpts = [
      "fido2-device=auto"
      "token-timeout=120"
    ];
  };
}
