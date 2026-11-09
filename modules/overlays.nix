# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
{inputs, ...}: {
  nixpkgs.overlays = [
    #  Packages from the justaguylinux flake inputs (justaguy.dev/drew).
    #  Exposed through pkgs so modules consume pkgs.ghee / pkgs.butterpal
    #  instead of reaching into inputs.* directly.
    (final: prev: {
      ghee = inputs.ghee.packages.${final.stdenv.hostPlatform.system}.ghee;
      butterpal = inputs.butterpal.packages.${final.stdenv.hostPlatform.system}.butterpal;
    })

    # typescript-language-server 6.0.2 (used by nixvim/neovim) ships a stale
    # pnpm dependency hash in the pinned nixpkgs revision (7fd4004, Oct 11 2026):
    #   declared: sha256-MUSxDMlbG21KSesGdEvqa2kEpuVfLlXRUX1qV/FGsSo=
    #   actual:   sha256-xR/EF60lVBsITKgH7wCM2wHM46PFQevD51KfCENSUH4=
    # Upstream fixed this in NixOS/nixpkgs@ac7b1aa ("typescript-language-server:
    # fix pnpm hash"), but that commit is only on master and has not landed in
    # the nixos-unstable branch we track yet, so patch it locally for now.
    # TODO: remove this overlay once nixos-unstable contains ac7b1aa.
    (final: prev: {
      typescript-language-server = prev.typescript-language-server.overrideAttrs (old: {
        pnpmDeps = old.pnpmDeps.override {
          hash = "sha256-xR/EF60lVBsITKgH7wCM2wHM46PFQevD51KfCENSUH4=";
        };
      });
    })

    # mcat-unwrapped 0.6.7 fails since nixpkgs f4a03c0 (2026-11-07): the cargo
    # setup hook (cargoUseSystemLibs) now exports AWS_LC_SYS_USE_SYSTEM=1 and
    # RUSTONIG_SYSTEM_LIBONIG=1, but the package declares neither aws-lc,
    # oniguruma nor pkg-config (both build scripts discover the system library
    # via pkg-config), so aws-lc-sys and onig_sys panic. Supply all three.
    # TODO: remove once nixpkgs fixes mcat-unwrapped.
    (final: prev: {
      mcat-unwrapped = prev.mcat-unwrapped.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [final.pkg-config];
        buildInputs = (old.buildInputs or []) ++ [final.aws-lc final.oniguruma];
      });
    })

    # lstr 0.4.0 fails for the same reason since nixpkgs f4a03c0: the hook
    # exports LIBGIT2_NO_VENDOR=1, but the package only declares openssl, so
    # libgit2-sys finds no libgit2.pc and panics. Supply libgit2.
    # TODO: remove once nixpkgs fixes lstr.
    (final: prev: {
      lstr = prev.lstr.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [final.pkg-config];
        buildInputs = (old.buildInputs or []) ++ [final.libgit2];
      });
    })
  ];
}
