# docker, distrobox, qemu without libvirt, Kubernetes CLI (NixOS.md 2.9)
{
  pkgs,
  lib,
  username,
  ...
}: {
  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
  };
  virtualisation.libvirtd.enable = lib.mkForce false;
  virtualisation.podman.enable = lib.mkForce false;

  users.users.${username}.extraGroups = ["docker"];

  environment.systemPackages = with pkgs; [
    distrobox
    docker-buildx
    docker-compose
    nerdctl
    qemu
    kubectl
    kubernetes-helm
    kustomize
    fluxcd
    k9s
    kubeconform
    krew
  ];
}
