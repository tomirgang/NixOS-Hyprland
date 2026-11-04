# Packages for this host only (KooL convention). Applications: local/apps.nix
{pkgs, ...}: let
  python-packages = pkgs.python3.withPackages (
    ps:
      with ps; [
        requests
      ]
  );
in {
  environment.systemPackages = [python-packages];
}
