# Embedded: PlatformIO and ESP-IDF (NixOS.md 2.12): nix develop .#embedded
# ESP-IDF comes from github:mirrexagon/nixpkgs-esp-dev (own nixpkgs pin).
{
  pkgs,
  inputs,
  system,
}:
pkgs.mkShell {
  packages = [
    pkgs.platformio-core
    pkgs.esptool
    inputs.esp-dev.packages.${system}.esp-idf-full
  ];
}
