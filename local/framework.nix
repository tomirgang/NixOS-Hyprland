# Framework Laptop 13 (13th Gen Intel): firmware, graphics, fingerprint,
# framework-control, energy (NixOS.md 2.5).
# The nixos-hardware profile is imported in flake.nix for nixosConfigurations.frame
# only, so that frame-vm evaluates without it.
{pkgs, ...}: {
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  services.fwupd.enable = true;
  services.fprintd.enable = true;
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;
  hardware.i2c.enable = true; # ddcutil for external monitors
  hardware.sensor.iio.enable = true;

  environment.systemPackages = with pkgs; [
    framework-tool
    ddcutil
    brightnessctl
  ];

  # No suspend, no hibernation. Closing the lid only locks.
  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };
  services.upower = {
    enable = true;
    percentageAction = 5;
    criticalPowerAction = "PowerOff";
  };

  # framework-control: fan curve service with web UI on 127.0.0.1:30912
  # (nixpkgs package and module, built from source). The config is copied
  # (mode), not linked, so the web UI can save changes; every activation
  # resets it to the state in the flake.
  services.framework-control.enable = true;
  environment.etc."framework-control/config.json" = {
    source = ./framework-control.json;
    mode = "0644";
  };
}
