# Packages for this host only (KooL convention). Applications: local/apps.nix
{pkgs, ...}: let
  python-packages = pkgs.python3.withPackages (
    ps:
      with ps; [
        requests
        pyquery # needed for hyprland-dots Weather script
      ]
  );
in {
  environment.systemPackages = [python-packages];
}
