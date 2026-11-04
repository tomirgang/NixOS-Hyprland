# Desktop applications and system tools (NixOS.md 2.12, way S).
# Flatpak stays enabled as fallback only (hosts/frame/config.nix).
{pkgs, ...}: let
  # gnome-calendar opens "Open in Settings" and the online account link via
  # the D-Bus name org.gnome.Settings (action launch-panel). GNOME Settings
  # hides panels whose desktop file says OnlyShowIn=GNOME, which applies to
  # online-accounts under Hyprland. The wrapper sets XDG_CURRENT_DESKTOP for
  # this process only, the D-Bus service file is rewritten to the wrapper.
  gnome-settings = pkgs.symlinkJoin {
    name = "gnome-control-center-hyprland";
    paths = [pkgs.gnome-control-center];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/gnome-control-center \
        --set XDG_CURRENT_DESKTOP GNOME
      svc=$out/share/dbus-1/services/org.gnome.Settings.service
      rm $svc
      sed "s|^Exec=[^ ]*|Exec=$out/bin/gnome-control-center|" \
        ${pkgs.gnome-control-center}/share/dbus-1/services/org.gnome.Settings.service > $svc
    '';
  };
in {
  environment.systemPackages = with pkgs; [
    # Browser, mail, feeds
    chromium
    google-chrome
    thunderbird
    liferea

    # Office, text, notes
    mousepad
    pandoc
    markdownlint-cli
    obsidian
    # logseq: nixpkgs 0.10.15 needs electron-39 (end of life, marked insecure);
    # Flatpak fallback com.logseq.Logseq (NixOS.md 2.14)

    # Passwords, crypto, YubiKey
    keepassxc
    bitwarden-desktop
    age
    sops
    yubikey-manager
    yubioath-flutter
    libfido2
    pam_u2f # pamu2fcfg

    # Graphics, photo, diagrams
    gimp
    inkscape
    digikam
    drawio

    # Media, audio
    ffmpegthumbnailer
    obs-studio
    simplescreenrecorder
    pavucontrol

    # Files, cloud, misc desktop
    kdePackages.dolphin
    filezilla
    ranger
    nextcloud-client
    crow-translate
    qalculate-gtk
    simple-scan
    gnome-settings # see let block, needed by gnome-calendar

    # Terminals and editors (kitty, ghostty, wezterm come from KooL)
    gtkterm
    vim
    nano
    vscode
    zed-editor
    claude-code

    # Monitoring
    nvtopPackages.intel
    smartmontools
    lm_sensors

    # Network
    dnsutils
    traceroute
    netcat-openbsd
    inetutils
    wireguard-tools

    # Imaging (balena-etcher is not reliably in nixpkgs)
    bmaptool
    caligula
  ];

  # Backend for gnome-calendar (home/tom.nix): calendar sources, reminders
  # and the "Manage Calendars" dialog need the EDS D-Bus services
  services.gnome.evolution-data-server.enable = true;
  # Online accounts (Google, Nextcloud, Microsoft) for gnome-calendar: goa-daemon
  # as D-Bus service, the panel comes from the wrapped GNOME Settings above
  services.gnome.gnome-online-accounts.enable = true;

  # Printing (Brother laser) and scanning
  services.printing = {
    enable = true;
    drivers = [pkgs.brlaser];
  };
  # Brother DCP-1612W (reports itself as DCP-1610W series) over WLAN. The
  # mDNS name follows the MAC address and survives a DHCP address change.
  # Raw socket on port 9100: the IPP service on port 631 answers /ipp/print
  # with 404 despite advertising it via mDNS (rp=ipp/print).
  hardware.printers.ensurePrinters = [
    {
      name = "Brother_DCP-1612W";
      description = "Brother DCP-1612W";
      deviceUri = "socket://BRNF889D2DD4E78.local:9100";
      model = "drv:///brlaser.drv/br1610.ppd";
      ppdOptions.PageSize = "A4";
    }
  ];
  # The device offers no eSCL/AirScan, only the proprietary Brother protocol
  # (port 54921), hence brscan4 (unfree).
  hardware.sane = {
    enable = true;
    brscan4 = {
      enable = true;
      netDevices.dcp1612w = {
        model = "DCP-1610W";
        nodename = "BRNF889D2DD4E78.local";
      };
    };
  };
  # Default browser system-wide (SUPER B opens the default browser);
  # ~/.config/mimeapps.list takes precedence if present
  xdg.mime.defaultApplications = {
    "text/html" = "google-chrome.desktop";
    "x-scheme-handler/http" = "google-chrome.desktop";
    "x-scheme-handler/https" = "google-chrome.desktop";
    "x-scheme-handler/about" = "google-chrome.desktop";
    "x-scheme-handler/unknown" = "google-chrome.desktop";
  };
  environment.sessionVariables.EDITOR = "vim";
  environment.sessionVariables.VISUAL = "code --wait";

  # The hypridle unit has a minimal PATH that hyprlock inherits when hypridle
  # starts it. KooL's scripts need bash and notify-send from the system profile
  # (Battery.sh in hyprlock, WallpaperDaemon.sh and notifications in hypridle)
  # and wallust and awww from the user profile (WallustSwww.sh after resume).
  systemd.user.services.hypridle.path = [
    "/run/current-system/sw"
    "/etc/profiles/per-user/tom"
  ];
  # hyprlock runs in the cgroup of hypridle. With the default control-group
  # mode a stop or restart of hypridle kills it and leaves the session locked.
  systemd.user.services.hypridle.serviceConfig.KillMode = "process";
}
