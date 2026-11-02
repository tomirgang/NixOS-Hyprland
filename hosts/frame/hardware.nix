# PLACEHOLDER until Phase 3: replaced by the output of
#   nixos-generate-config --root /mnt --show-hardware-config
# Kept evaluable so that nixosConfigurations.frame builds before installation.
# Layout as in NixOS.md 2.3 and Phase 3: ESP vfat (label ESP), root ext4
# (label nixos) on LV frame-vg/root.
{
  lib,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  boot.initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod"];
  boot.kernelModules = ["kvm-intel"];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
