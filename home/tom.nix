# Home Manager for tom (NixOS.md 2.11): bash, git, gpg, CLI, user units, PATH.
# The KooL-managed directories in ~/.config (hypr, waybar, rofi, kitty,
# quickshell, starship, yazi, btop, ...) are not touched here. Of the KooL
# Home Manager modules only the Hyprland package set is used; git, btop, yazi,
# ghostty, eza, tmux, nixvim and the overview would write into those
# directories or clash with the settings below.
{pkgs, ...}: {
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
  ];

  systemd.user.services.lean-ctx-proxy = {
    Unit.Description = "lean-ctx API Proxy";
    Service = {
      ExecStart = "${pkgs.lean-ctx}/bin/lean-ctx proxy start --port=4444";
      Restart = "on-failure";
    };
    Install.WantedBy = ["default.target"];
  };
}
