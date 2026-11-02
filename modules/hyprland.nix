# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#  Hyprland session (NixOS level).
#
#  Only what has to exist outside a user session lives here: the session
#  itself, its login/portal wiring, and the polkit authentication agent.
#  User-facing Hyprland/Wayland tooling lives in modules/home/hyprland.nix.
#
#  The Hyprland configuration is NOT managed by Nix. The KoolDots dotfiles are
#  copied into ~/.config/hypr by the installer and use hyprland.lua as their
#  entry point, so Home Manager's wayland.windowManager.hyprland module must
#  stay disabled: it always writes ~/.config/hypr/hyprland.conf, which Hyprland
#  would then load in preference to hyprland.lua.
{
  config,
  pkgs,
  inputs,
  username,
  ...
}: {
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    # package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland; # hyprland-git
    # portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland; # xdph-git
    xwayland.enable = true;
  };

  programs.hyprlock.enable = true;

  # Waybar is started by the Hyprland dotfiles. Enabling the module starts a
  # second bar on top of the dotfiles' one.
  programs.waybar.enable = false;

  # Polkit authentication agent for the Hyprland session: the unit shipped
  # with hyprpolkitagent (share/systemd/user), started with the graphical
  # session. The dotfiles' Polkit.sh finds the running agent and skips.
  systemd.packages = [pkgs.hyprpolkitagent];
  systemd.user.services.hyprpolkitagent = {
    wantedBy = ["graphical-session.target"];
    after = ["dbus.service"];
  };

  # hyprpolkitagent registers with polkitd only once at startup. When polkitd
  # restarts (nixos-rebuild switch), the registration is lost and every polkit
  # authentication fails with "no agent is available". Restart the agent of
  # the user session once polkitd is ready again. try-restart is a no-op when
  # the agent is not running; without a user manager (boot) the call fails and
  # the leading "-" ignores it.
  systemd.services.polkit.serviceConfig.ExecStartPost = [
    "-${config.systemd.package}/bin/systemctl --user --machine=${username}@.host try-restart hyprpolkitagent.service"
  ];

  # Session-level helpers that the programs.hyprland module does not provide on
  # its own. Everything else that is Hyprland/Wayland related is in
  # modules/home/hyprland.nix.
  environment.systemPackages = with pkgs; [
    uwsm # session launcher behind programs.hyprland.withUWSM
    hyprpolkitagent # agent behind the unit above
    kdePackages.polkit-kde-agent-1 # alternative agent kept available
  ];

  # TODO: package hyprland-config, hyprland-monitors, hyprland-schema,
  # hyprland-socket and hyprland-state on PyPI or as local overlays, then expose
  # them through the flake's customPkgs. See docs/HYPRMOD.md.
}
