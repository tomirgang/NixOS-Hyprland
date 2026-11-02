# C++ with Qt6 and Vulkan tooling (NixOS.md 2.13): nix develop .#cpp-qt6
{pkgs}:
pkgs.mkShell {
  inputsFrom = [(import ./cpp.nix {inherit pkgs;})];
  packages = with pkgs; [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland
    qt6.qtsvg
    qt6.qtcharts
    qt6.qt3d
    qt6.qt5compat
    qt6.qtshadertools
    qt6.qttools
    kdePackages.polkit-qt-1
    glslang
    spirv-tools
    vulkan-validation-layers
  ];
}
