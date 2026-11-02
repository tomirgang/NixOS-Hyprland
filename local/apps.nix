# Desktop applications and system tools (NixOS.md 2.12, way S).
# Flatpak stays enabled as fallback only (hosts/frame/config.nix).
# Claude Desktop: no nixpkgs package; open point in NixOS.md section 4.
{pkgs, ...}: {
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
    calibre
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

  # Printing (Brother laser) and scanning
  services.printing = {
    enable = true;
    drivers = [pkgs.brlaser];
  };
  hardware.sane.enable = true;
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
}
