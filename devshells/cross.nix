# Cross compilers as on Debian (gcc-<target>-linux-gnu): nix develop .#cross
# Each compiler is prefixed (aarch64-unknown-linux-gnu-gcc, ...).
{pkgs}:
pkgs.mkShell {
  packages = with pkgs.pkgsCross; [
    aarch64-multiplatform.stdenv.cc
    armv5tel-multiplatform.stdenv.cc # armel
    ppc64.stdenv.cc
    riscv64.stdenv.cc
    s390x.stdenv.cc
    loongarch64-linux.stdenv.cc
    gnu32.stdenv.cc # i686
  ];
}
