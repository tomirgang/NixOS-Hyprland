# LUKS2 -> LVM frame-vg -> LV root (NixOS.md 2.3). Real host only.
# Unlocking with the YubiKey (FIDO2) after
#   sudo systemd-cryptenroll --fido2-device=auto /dev/disk/by-partlabel/cryptroot
# the passphrase stays as second key slot.
# token-timeout: without the YubiKey systemd-cryptsetup waits 120 s for it,
# then asks for the passphrase (crypttab(5); the PIN prompt is not limited).
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

  # The LV root appears only after the unlock. The default device timeout of
  # 90 s runs from the start of the initrd, so 120 s token wait plus typing
  # the passphrase would end in the emergency shell. The mapper device
  # itself already has no timeout (systemd-cryptsetup-generator).
  fileSystems."/".options = ["x-systemd.device-timeout=0"];
}
