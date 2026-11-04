# Home Manager for tom (NixOS.md 2.11): bash, git, gpg, CLI, user units, PATH.
# The KooL-managed directories in ~/.config (hypr, waybar, rofi, kitty,
# quickshell, starship, yazi, btop, ...) are not touched here, except the
# hyprlock configs at the end of this file. Of the KooL
# Home Manager modules only the Hyprland package set is used; git, btop, yazi,
# ghostty, eza, tmux, nixvim and the overview would write into those
# directories or clash with the settings below.
{pkgs, ...}: let
  # Update routine (NixOS_TODO.md, Phase 5), alias nix_update
  frameUpdate = pkgs.writeShellApplication {
    name = "frame-update";
    runtimeInputs = with pkgs; [git nix nh vulnix coreutils];
    text = builtins.readFile ./frame-update.sh;
  };
  # User-level tools (flatpak, rustup, cargo, go, uv, krew), then frame-update;
  # alias update_all. The tools themselves come from PATH, not from Nix.
  updateAll = pkgs.writeShellApplication {
    name = "update-all";
    runtimeInputs = [frameUpdate];
    text = builtins.readFile ./update-all.sh;
  };
in {
  imports = [
    ../modules/home/hyprland.nix
  ];

  programs.bash = {
    enable = true;
    shellAliases = {
      ls = "lsd";
      l = "ls -l";
      la = "ls -a";
      lla = "ls -la";
      lt = "ls --tree";
      nix_update = "frame-update";
      update_all = "update-all";
    };
    initExtra = ''
      fastfetch -c $HOME/.config/fastfetch/config-compact.jsonc
      # Imperative additions (lean-ctx hook, rtk, local tweaks)
      [ -f "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local"
    '';
  };
  # Configuration stays KooL-managed (~/.config/starship.toml)
  programs.starship.enable = true;

  home.sessionPath = [
    "$HOME/bin"
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/go/bin"
    "$HOME/.krew/bin"
  ];

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "Tom Irgang";
        email = "thomas@irgang.eu";
        signingkey = "CC5E9F5537C72B26A006F1A8C4F1E9B07FAB41ED";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "vim";
      commit.gpgsign = true;
      tag.gpgsign = true;
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.fzf.enable = true;
  programs.zoxide.enable = true;

  home.packages = with pkgs; [
    ripgrep
    fd
    tmux
    screen
    w3m
    jq
    socat
    rsync
    lean-ctx
    rtk
    vulnix
    frameUpdate
    updateAll
    zettlr
    marktext
    bat
    just
    planify
    gnome-calendar
    kubectl
    kubecolor
    keyutils
    pstree

    nnn # terminal file manager

    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processor https://github.com/mikefarah/yq
    eza # A modern replacement for ‘ls’
    fzf # A command-line fuzzy finder

    # networking tools
    mtr # A network diagnostic tool
    iperf3
    dnsutils  # `dig` + `nslookup`
    ldns # replacement of `dig`, it provide the command `drill`
    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing
    ipcalc  # it is a calculator for the IPv4/v6 addresses

    # misc
    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg

    # nix related
    #
    # it provides the command `nom` works just like `nix`
    # with more details log output
    nix-output-monitor

    # productivity
    hugo # static site generator
    glow # markdown previewer in terminal

    btop  # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb
  ];

  # KooL's initial-boot.sh sets Flat-Remix themes once, which are not
  # installed here; GTK apps then lack icons. Use the themes from
  # modules/theme.nix instead.
  dconf.settings."org/gnome/desktop/interface" = {
    gtk-theme = "Adwaita-dark";
    icon-theme = "Papirus-Dark";
  };

  systemd.user.services.lean-ctx-proxy = {
    Unit.Description = "lean-ctx API Proxy";
    Service = {
      ExecStart = "${pkgs.lean-ctx}/bin/lean-ctx proxy start --port=4444";
      Restart = "on-failure";
    };
    Install.WantedBy = ["default.target"];
  };

  # hyprlock: the only KooL files in ~/.config/hypr managed here. Changed from
  # KooL: the input field shows the PAM prompt ($PAMPROMPT), so the lock
  # screen asks for the YubiKey PIN or the password, whichever PAM wants.
  # KooL's HyprlockWallpaperSelect.sh skips symlinked configs; the background
  # path .wallpaper_current is updated by that script anyway.
  xdg.configFile = builtins.listToAttrs (map (name: {
      name = "hypr/${name}";
      value.source = ./hyprlock/${name};
    }) [
      "hyprlock.conf"
      "hyprlock-2k.conf"
      "hyprlock-1080p.conf"
    ]);
}
