# User tom. Login shell bash (NixOS.md 2.11); groups from Debian minus
# libvirt, plugdev, netdev (no such groups on NixOS or no longer needed).
{
  pkgs,
  username,
  ...
}: let
  inherit (import ./variables.nix) gitUsername;
in {
  users = {
    mutableUsers = true;
    users.${username} = {
      isNormalUser = true;
      description = gitUsername;
      shell = pkgs.bashInteractive;
      extraGroups = [
        "wheel"
        "networkmanager"
        "audio"
        "video"
        "input"
        "dialout"
        "scanner"
        "lp"
        "kvm"
        # docker, wireshark, sispmctl: added by the modules that create the groups
      ];
    };
  };
}
