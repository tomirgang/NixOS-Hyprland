# Global development base, nix-ld for foreign binaries (NixOS.md 2.13).
# Compilers for C/C++, Qt6, cross targets, embedded and docs: devshells/.
{pkgs, ...}: {
  # Libraries for prebuilt binaries in ~/.local/bin, ~/.cargo/bin, uv Pythons,
  # PlatformIO, ESP-IDF and the VS Code remote server. Merges with the list in
  # modules/packages.nix and the module defaults.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    openssl
    glib
    libGL
    libx11
    libxkbcommon
    wayland
    fontconfig
    freetype
    dbus
    nss
    alsa-lib
  ];

  environment.systemPackages = with pkgs; [
    git
    git-lfs
    gh
    mercurial
    uv
    rustup
    go
    ruby
    nodejs
    python3
    lua5_4
    gnumake
    gcc
    nil
    nixd
    nixfmt
  ];
}
