# Kubernetes work beyond the global CLI set (local/virtualisation.nix):
# nix develop .#k8s
{pkgs}:
pkgs.mkShell {
  packages = with pkgs; [
    kubectl
    kubernetes-helm
    kustomize
    fluxcd
    kubeconform
    kubectl-cnpg
    sops
    age
    ansible
    ansible-lint
  ];
}
