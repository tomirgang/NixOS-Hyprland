# Claude Desktop: official Debian package from Anthropic's APT repository,
# repackaged (bundled Electron, proprietary). Not in nixpkgs.
# Update: version and hash from
#   https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libcap_ng,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libseccomp,
  libsecret,
  libxkbcommon,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  vulkan-loader,
  xdg-utils,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "claude-desktop";
  version = "4.4212.0";

  src = fetchurl {
    url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${finalAttrs.version}_amd64.deb";
    hash = "sha256:4fcf658e0fc895390ab82593287281dfbce261b0ec3ea90060e82d8bfbfd7a84";
  };

  nativeBuildInputs = [dpkg autoPatchelfHook makeWrapper wrapGAppsHook3];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libcap_ng
    libdrm
    libgbm
    libseccomp
    libxkbcommon
    nspr
    nss
    pango
    pipewire
    systemd
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
  ];

  dontWrapGApps = true;

  # setuid chrome-sandbox cannot be unpacked in the sandbox; Electron uses
  # the user namespace sandbox instead
  unpackPhase = "dpkg-deb --fsys-tarfile $src | tar -x --no-same-owner --no-same-permissions";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib $out/bin
    cp -r usr/lib/claude-desktop $out/lib/
    cp -r usr/share $out/share
    rm -rf $out/share/lintian $out/share/doc
    runHook postInstall
  '';

  # Runtime-loaded libraries (GL, Vulkan, notifications, keyring) and
  # Wayland via Ozone (NIXOS_OZONE_WL is set system-wide)
  postFixup = ''
    makeWrapper $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [libGL vulkan-loader libnotify libsecret systemd]} \
      --prefix PATH : ${lib.makeBinPath [xdg-utils]} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"
  '';

  meta = {
    description = "Desktop application for Claude.ai";
    homepage = "https://claude.ai/download";
    license = lib.licenses.unfree;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    platforms = ["x86_64-linux"];
    mainProgram = "claude-desktop";
  };
})
