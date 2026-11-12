# YubiKey, PAM-U2F, GnuPG, greetd, firewall, SSH (NixOS.md 2.6, 2.7)
{
  config,
  pkgs,
  lib,
  username,
  ...
}: let
  # pam_u2f does not wait for a device: without the YubiKey it fails at once
  # and pam_unix asks for the password. At the greetd login after boot the
  # key gets 120 s to show up first, the same time as token-timeout for the
  # LUKS unlock (hosts/frame/luks.nix). Always exits 0, the rule is optional;
  # after the timeout pam_u2f finds no device and the password prompt follows.
  # pam_exec passes only the PAM environment, so PATH is set here.
  yubikeyWait = pkgs.writeShellScript "yubikey-wait" ''
    PATH=${lib.makeBinPath [pkgs.coreutils pkgs.gnugrep]}
    present() {
      ${pkgs.libfido2-nopcsc}/bin/fido2-token -L 2>/dev/null | grep -q '^/dev/hidraw'
    }
    present && exit 0
    echo "YubiKey not found, waiting up to 2 minutes"
    for ((i = 0; i < 120; i++)); do
      sleep 1
      present && exit 0
    done
    echo "No YubiKey, password login"
    exit 0
  '';
in {
  # YubiKey (OTP, U2F, CCID)
  services.pcscd.enable = true;
  services.udev.packages = [pkgs.yubikey-personalization];

  # libfido2 in nixpkgs is built with PC/SC. With pcscd running it reports the
  # YubiKey twice (hidraw and pcsc://slot0); ssh then waits for a "select by
  # touch" that times out with "device not found". OpenSSH and pam_u2f use a
  # libfido2 without PC/SC, as on Debian. pam_u2f is a leaf package and is
  # replaced by an overlay; openssh only via programs.ssh.package, an overlay
  # would rebuild everything that depends on it.
  nixpkgs.overlays = [
    (final: prev: {
      libfido2-nopcsc = prev.libfido2.override {withPcsclite = false;};
      pam_u2f = prev.pam_u2f.override {libfido2 = final.libfido2-nopcsc;};
    })
  ];
  programs.ssh.package = pkgs.openssh.override {libfido2 = pkgs.libfido2-nopcsc;};

  # askpass for FIDO2 PIN and touch prompts without a TTY (git from GUI/IDE).
  # Key passphrases in the agent go through gpg-agent and pinentry instead.
  # Qt6 and native Wayland; KWallet is only used if it is running.
  programs.ssh = {
    enableAskPassword = true;
    askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
  };

  # U2F as sufficient factor, password stays as fallback. Mapping files as on
  # Debian (yubikey-setup-plan.md 3.5): root-owned under /etc/u2f with the
  # fixed origin pam://yk-linux, independent of the hostname.
  #   /etc/u2f/sudo   touch only        (sudo, polkit)
  #   /etc/u2f/login  PIN + touch (-N)  (login, hyprlock; greetd includes login)
  # The files are not managed by Nix; restore them from the Debian archive or
  # create them with pamu2fcfg, then chown root:root and chmod 644.
  security.pam.u2f = {
    enable = true;
    control = "sufficient";
    settings = {
      authfile = "/etc/u2f/sudo";
      origin = "pam://yk-linux";
      appid = "pam://yk-linux";
      cue = true;
      pinverification = 0;
      userpresence = 1;
    };
  };
  security.pam.services = let
    # PIN + touch for interactive logins and the lock screen
    u2fLogin = {
      u2fAuth = true;
      rules.auth.u2f.settings = {
        authfile = lib.mkForce "/etc/u2f/login";
        pinverification = lib.mkForce 1;
        nouserok = true;
      };
    };
  in {
    login = u2fLogin;
    hyprlock = u2fLogin;
    # Only greetd waits; login itself (tty), hyprlock and sudo fall back to
    # the password at once. Runs before the login substack with pam_u2f.
    greetd.rules.auth.yubikey-wait = {
      order = config.security.pam.services.greetd.rules.auth.login.order - 50;
      control = "optional";
      modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
      args = ["quiet" "stdout" "${yubikeyWait}"];
    };
    sudo.u2fAuth = true;
    polkit-1.u2fAuth = true;
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
