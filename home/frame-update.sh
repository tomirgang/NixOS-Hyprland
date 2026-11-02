# frame-update: update routine of host frame (alias nix_update).
#   1. flake inputs update (nixpkgs with security fixes, Home Manager, ...)
#   2. build and switch with nh (shows the package diff, asks before switch)
#   3. commit flake.lock (signed) and push to origin
#   4. vulnix scan of the running system
# On a failed build or a declined switch flake.lock is reset.
# Options: --no-push, --no-scan
set -euo pipefail

repo="${NH_FLAKE:-$HOME/git/nixos-config}"
push=1
scan=1
for arg in "$@"; do
  case "$arg" in
    --no-push) push=0 ;;
    --no-scan) scan=0 ;;
    *) echo "usage: nix_update [--no-push] [--no-scan]" >&2; exit 2 ;;
  esac
done

cd "$repo"
if [ -n "$(git status --porcelain)" ]; then
  echo "Uncommitted changes in $repo; commit or stash them first:" >&2
  git status --short >&2
  exit 1
fi

echo "==> nix flake update"
nix flake update

if git diff --quiet flake.lock; then
  echo "==> flake.lock unchanged, nothing to switch"
else
  git --no-pager diff --stat flake.lock
  echo "==> nh os switch"
  if ! nh os switch --ask "$repo"; then
    echo "Switch failed or declined; resetting flake.lock" >&2
    git checkout -- flake.lock
    exit 1
  fi
  git add flake.lock
  git commit -m "flake.lock: update $(date +%F)"
  if [ "$push" -eq 1 ]; then
    git push
  fi
fi

if [ "$scan" -eq 1 ]; then
  echo "==> vulnix --system (known CVEs of the running system)"
  # Findings set a non-zero exit code; the scan is a report, not a failure
  vulnix --system || echo "==> vulnix exit code $?: findings above (or scan error)"
fi

echo "==> not covered here: flatpak update, rustup update, cargo/go/uv/krew tools (NixOS_TODO.md 5.6)"
