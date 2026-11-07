# Electronics and embedded tools with udev rules (NixOS.md 2.12)
{
  pkgs,
  username,
  ...
}: {
  environment.systemPackages = with pkgs; [
    kicad
    fritzing
    sigrok-cli
    pulseview
    sigrok-firmware-fx2lafw
    openhantek6022
    sispmctl
    usbrelay
    platformio-core
  ];

  services.udev.packages = with pkgs; [
    libsigrok
    openhantek6022
    platformio-core.udev
    usbrelay
  ];

  # The udev rules of libsigrok and openhantek6022 assign GROUP="plugdev"
  users.groups.plugdev = {};

  # sispmctl (Gembird power strips): rules as in Debian 60-sispmctl.rules
  users.groups.sispmctl = {};
  users.users.${username}.extraGroups = ["sispmctl" "plugdev"];
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="04b4", ATTR{idProduct}=="fd1[0-35]", GROUP="sispmctl", MODE="0660"
  '';
}
