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
  services.fprintd.enable = false;
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;
  hardware.i2c.enable = true; # ddcutil for external monitors
  hardware.sensor.iio.enable = true;

  # HP Thunderbolt Dock G4: the dock's USB2 hub (usb 3-2) does not answer until
  # the Thunderbolt link is up at about 5 s. With the default timeout of 5000 ms
  # the retries block the root hub until about 23 s, including the YubiKey and
  # the keyboard at the LUKS prompt.
  boot.kernelParams = ["usbcore.initial_descriptor_timeout=1000"];
  # Without i915 in the initrd the external monitors stay dark at the LUKS
  # prompt and the kernel tears down the inactive DP tunnel of the firmware.
  boot.initrd.kernelModules = ["i915"];
  # Without boltd the dock stays unauthorized (security=user) and its PCIe
  # part is missing. Enroll once: boltctl enroll --policy auto <uuid>
  services.hardware.bolt.enable = true;

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

  # The monitors on the dock do not reliably sleep after power off, so they are
  # set to DPM off over DDC/CI. Runs on power off only, not on reboot or switch.
  # Addressed by serial number, display numbers are not stable. Errors are
  # ignored and the timeout keeps a hanging DDC bus from delaying the shutdown.
  systemd.services.monitors-off-at-poweroff = {
    description = "Set external monitors to DPM off before power off";
    wantedBy = ["poweroff.target"];
    after = ["plymouth-poweroff.service"];
    before = ["systemd-poweroff.service"];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = 15;
      ExecStart = map (sn: "-${pkgs.ddcutil}/bin/ddcutil --sn ${sn} setvcp D6 4") [
        "6CM94516S6"
        "6CM9480P8K"
      ];
    };
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
