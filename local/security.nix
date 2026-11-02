# YubiKey, PAM-U2F, GnuPG, greetd, firewall, SSH (NixOS.md 2.6, 2.7)
{
  pkgs,
  lib,
  username,
  ...
}: {
  # YubiKey (OTP, U2F, CCID)
  services.pcscd.enable = true;
  services.udev.packages = [pkgs.yubikey-personalization];

  # U2F as sufficient factor; authfile default ~/.config/Yubico/u2f_keys,
  # bound to origin pam://frame (same hostname as on Debian)
  security.pam.u2f = {
    enable = true;
    control = "sufficient";
    settings.cue = true;
  };
  security.pam.services = {
    login.u2fAuth = true;
    sudo.u2fAuth = true;
    polkit-1.u2fAuth = true;
    hyprlock.u2fAuth = true;
    greetd = {
      u2fAuth = true;
      fprintAuth = true;
    };
    sshd = {
      unixAuth = lib.mkForce true;
      u2fAuth = false;
      fprintAuth = false;
    };
  };

  # KeePassXC provides the Secret Service, not gnome-keyring
  services.gnome.gnome-keyring.enable = lib.mkForce false;
  programs.seahorse.enable = lib.mkForce false;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };

  # Login: greetd with tuigreet instead of GDM/ly. KooL starts Hyprland via
  # UWSM (programs.hyprland.withUWSM in modules/hyprland.nix).
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start -- hyprland-uwsm.desktop'";
      user = "greeter";
    };
  };

  # Firewall replaces ufw (migration/ufw.txt). Rules 2 and 3 (10.42/16 and
  # 10.43/16, k3s pod and service networks) are not taken over, the clusters
  # are gone. Rule 4 (deny 224.0.0.0/4) is implicit in the default deny; mDNS
  # for avahi is opened by services.avahi.openFirewall (default true).
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    # Rule 1: TFTP for flashing over the USB network adapter
    interfaces."enxa0cec8655356".allowedUDPPorts = [69];
  };

  # SSH host keys are generated new, not taken over
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
    extraConfig = ''
      Match Address 192.168.0.0/16,10.0.0.0/8
        PasswordAuthentication yes
    '';
  };

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };
  users.users.${username}.extraGroups = ["wireshark"];
}
