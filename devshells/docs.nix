# Documentation toolchain (NixOS.md 2.13): nix develop .#docs
{pkgs}:
pkgs.mkShell {
  packages = with pkgs; [
    docbook-xsl-nons
    docbook_xml_dtd_45
    fop
    libxslt # xsltproc
    python3Packages.sphinx
    texinfo
    groff
  ];
}
