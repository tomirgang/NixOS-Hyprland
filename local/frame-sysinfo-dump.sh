# Dump system state that a file backup does not capture (system generation,
# store paths, partition table, LVM metadata, LUKS headers). Runs as root
# before each borgmatic run. A failing step is reported but does not abort
# the backup. NixOS variant of the Debian /usr/local/sbin/frame-sysinfo-dump.
out=${1:-/var/backups/frame}
install -d -m 700 "$out" "$out/luks"
rc=0
step() { "$@" || { echo "frame-sysinfo-dump: failed: $*" >&2; rc=1; }; }

step sh -c "/run/current-system/sw/bin/nixos-version --json > '$out/nixos-version.json'"
step sh -c "readlink /run/current-system > '$out/current-system.txt'"
step sh -c "nix-store -qR /run/current-system > '$out/store-paths.txt'"
step sh -c "flatpak list --app --columns=application > '$out/flatpak.txt'"
step sh -c "sfdisk -d /dev/nvme0n1 > '$out/sfdisk-nvme0n1.txt'"
step sh -c "vgcfgbackup -f '$out/lvm-%s.vg' > /dev/null"
step sh -c "lsblk -f > '$out/lsblk.txt'"

# one header backup per active LUKS mapping (root, FrameData, tomext if open)
for m in $(dmsetup ls --target crypt | awk '{print $1}'); do
  dev=$(cryptsetup status "$m" | awk '$1 == "device:" {print $2}')
  [ -n "$dev" ] || continue
  rm -f "$out/luks/$m.img"
  step cryptsetup luksHeaderBackup "$dev" --header-backup-file "$out/luks/$m.img"
done

step sh -c "systemctl list-unit-files --state=enabled > '$out/units-enabled.txt'"

[ "$rc" -eq 0 ] || echo "frame-sysinfo-dump: finished with errors" >&2
exit 0
