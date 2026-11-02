# Secure Boot with lanzaboote and own keys (NixOS.md 2.3, Phase 5).
# NOT imported before Phase 5. Order: sbctl create-keys, import this module
# and switch, sbctl verify, BIOS setup mode, sbctl enroll-keys --microsoft
# --firmware-builtin, enable Secure Boot, bootctl status.
{
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [inputs.lanzaboote.nixosModules.lanzaboote];

  environment.systemPackages = [pkgs.sbctl];
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
}
