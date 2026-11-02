# nixosConfigurations.frame-vm: test VM for
#   nixos-rebuild build-vm --flake .#frame-vm
# No LUKS, no FIDO2, no nixos-hardware. The file systems below only satisfy
# evaluation; build-vm replaces them with its own disk image.
{
  lib,
  pkgs,
  modulesPath,
  username,
  ...
}: {
  imports = [(modulesPath + "/profiles/qemu-guest.nix")];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.grub.enable = lib.mkForce false;
  nixpkgs.hostPlatform = "x86_64-linux";

  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 8192;
      cores = 4;
      diskSize = 20480;
      resolution = {
        x = 1920;
        y = 1200;
      };
      # GTK display aborts under a Wayland host (no EGL context), SDL works
      qemu.options = ["-vga none" "-device virtio-vga-gl" "-display sdl,gl=on"];
    };
    # SSH from the host for diagnosis: ssh -p 2222 tom@127.0.0.1
    virtualisation.forwardPorts = [
      {
        from = "host";
        host.address = "127.0.0.1";
        host.port = 2222;
        guest.port = 22;
      }
    ];
    services.openssh.settings.PasswordAuthentication = lib.mkForce true;
    services.openssh.settings.KbdInteractiveAuthentication = lib.mkForce true;
    # virgl offers only EGL configs without alpha channel; kitty needs one
    # on Wayland and aborts. VM only: kitty renders in software (llvmpipe).
    environment.systemPackages = [
      (lib.hiPrio (pkgs.writeShellScriptBin "kitty" ''
        LIBGL_ALWAYS_SOFTWARE=1 exec ${pkgs.kitty}/bin/kitty "$@"
      ''))
    ];
    # Test password, only inside the VM image
    users.users.${username}.initialPassword = "test";
    # No YubiKey in the VM: U2F stays sufficient, password works
    services.fprintd.enable = lib.mkForce false;
  };
}
