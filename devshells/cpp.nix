# C/C++ toolchain (NixOS.md 2.13): nix develop .#cpp
{pkgs}: let
  llvm = pkgs.llvmPackages_22;
in
  pkgs.mkShell.override {stdenv = pkgs.gcc16Stdenv;} {
    packages = with pkgs; [
      llvm.clang
      llvm.clang-tools # clangd, clang-tidy, clang-format
      llvm.lld
      llvm.lldb
      cmake
      meson
      ninja
      autoconf
      automake
      libtool
      bison
      flex
      pkg-config
      cppcheck
      gtest
    ];
  }
