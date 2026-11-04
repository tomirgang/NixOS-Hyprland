# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#  Hyprland / Wayland desktop tooling for the user session.
#
#  Packages only. Hyprland's own configuration is owned by the KoolDots
#  dotfiles in ~/.config/hypr (hyprland.lua), so nothing here generates
#  hyprland.conf and wayland.windowManager.hyprland stays disabled.
#  Session enablement (programs.hyprland, hyprlock, the polkit agent unit)
#  lives in modules/hyprland.nix.
{
  pkgs,
  inputs,
  ...
}: let
  waybarPkg = inputs.waybar.packages.${pkgs.stdenv.hostPlatform.system}.waybar.overrideAttrs (old: {
    doCheck = false;
    # The later -Dcava wins over the -Dcava=enabled set by nixpkgs' waybar.
    mesonFlags = (old.mesonFlags or []) ++ ["-Dtests=disabled" "-Dcava=disabled"];
  });
in {
  home.packages = with pkgs; [
    #  Bar and its modules
    waybarPkg

    #  Hyprland ecosystem
    hypridle
    hyprlang
    hyprshot
    hyprshutdown
    hyprcursor
    hyprland-qt-support # QML import path referenced by hosts/*/config.nix
    nwg-displays
    nwg-dock-hyprland
    nwg-look

    #  Wayland desktop tooling
    awww # wallpaper daemon
    wallust # colour scheme generation
    cliphist # clipboard history
    grim
    grimblast
    slurp
    swappy
    wl-clipboard
    wlr-randr
    wdisplays
    swaynotificationcenter
    wlogout
    rofi
    brightnessctl
    playerctl
    pamixer
    feh
    xdg-user-dirs # needed for copy.sh

    #  Qt theming on Wayland
    kdePackages.qt6ct
    kdePackages.qtwayland
    kdePackages.qtstyleplugin-kvantum # kvantum
    kdePackages.qtdeclarative

    #  Helpers used by the KoolDots dotfiles
    socat # Needed for Tak0 scripts
    ddcutil # Needed for ExternalBrightness script

    # Normally pulled in by hardware.graphics.enable; kept explicit so the
    # Hyprland GL stack does not depend on that toggle staying on.
    mesa
  ];
}
