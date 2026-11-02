# Host frame: Framework Laptop 13, 13th Gen Intel.
# Shared by nixosConfigurations.frame (hardware.nix, luks.nix, nixos-hardware)
# and nixosConfigurations.frame-vm (vm.nix). Hardware-specific settings live
# in local/framework.nix, everything else of the host here.
{
  pkgs,
  lib,
  host,
  options,
  ...
}: let
  inherit (import ./variables.nix) keyboardLayout;
in {
  imports = [
    ./users.nix
    ./packages-fonts.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = ["nowatchdog"];

    loader.systemd-boot.enable = true;
    loader.systemd-boot.configurationLimit = 15;
    loader.efi.canTouchEfiVariables = true;
    loader.timeout = 5;

    # The initrd is always systemd-based in nixos-unstable (FIDO2 unlocking)

    tmp.useTmpfs = false;

    # AppImage support (KooL default)
    binfmt.registrations.appimage = {
      wrapInterpreterInShell = false;
      interpreter = "${pkgs.appimage-run}/bin/appimage-run";
      recognitionType = "magic";
      offset = 0;
      mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
      magicOrExtension = ''\x7fELF....AI\x02'';
    };

    plymouth.enable = true;
  };

  # Swap only as zram, no swap LV, no hibernation
  swapDevices = [];
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
  };

  networking = {
    hostName = host;
    networkmanager.enable = true;
    networkmanager.plugins = lib.mkForce []; # openvpn, openconnect when needed
    timeServers = options.networking.timeServers.default;
  };
  services.resolved.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  # Console keymap generated from the xkb layout (EurKEY); also used in the
  # systemd initrd for the LUKS passphrase
  console.useXkbConfig = true;

  services = {
    xserver = {
      enable = false;
      xkb.layout = keyboardLayout;
    };
    gvfs.enable = true;
    tumbler.enable = true;
    udisks2.enable = true; # MountFrameData.sh
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    pulseaudio.enable = false;
    envfs.enable = true;
    fstrim.enable = true;
    libinput.enable = true;
    blueman.enable = true;
    smartd = {
      enable = true;
      autodetect = true;
    };
    flatpak.enable = true; # fallback only, no apps, no remote (NixOS.md 2.14)
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      Enable = "Source,Sink,Media,Socket";
      Experimental = true;
    };
  };

  security.rtkit.enable = true;
  security.polkit.enable = true;

  # KooL enables zsh globally; frame uses bash only (NixOS.md 2.1)
  programs.zsh.enable = lib.mkForce false;

  # KooL's polkit-agent unit calls lib.getExe hyprpolkitagent (bin/), the
  # binary lives in libexec/; the unit fails. hyprpolkitagent is started by
  # the dots and already runs, so the unit is not needed.
  systemd.user.services.polkit-agent.enable = lib.mkForce false;

  # KooL's nh module points to ~/NixOS-Hyprland
  programs.nh.flake = lib.mkForce "/home/tom/git/nixos-config";

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "@wheel"];
      # substituters = ["https://hyprland.cachix.org"]; # with the Hyprland flake input
      # trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
    };
    # Phase 5 (NixOS.md): nix.gc and nix.optimise
  };

  # Electron apps on Wayland, Qt QML path for KooL (KooL default)
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.sessionVariables.QML_IMPORT_PATH = builtins.concatStringsSep ":" [
    "${pkgs.hyprland-qt-support}/lib/qt-6/qml"
    "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
    "${pkgs.qt6.qt5compat}/lib/qt-6/qml"
  ];

  # First NixOS release on this host. Do not change after installation.
  system.stateVersion = "25.11";
}
