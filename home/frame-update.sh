# frame-update: update routine of host frame (alias nix_update).
#   1. flake inputs update (nixpkgs with security fixes, Home Manager, ...)
#   2. build and switch with nh (shows the package diff, asks before switch)
#   3. commit flake.lock (signed) and push to origin
#   4. hint when a new NixOS release is branched (release_hint)
#   5. vulnxscan of the running system, results in ~/.local/state/frame-update
# On a failed build or a declined switch flake.lock is reset.
# Options: --no-push, --no-scan, --claude (pre-assessment of new findings)
set -euo pipefail

repo="${NH_FLAKE:-$HOME/git/nixos-config}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/frame-update"
whitelist="$repo/home/vulnxscan-whitelist.csv"
push=1
scan=1
claude=0
for arg in "$@"; do
  case "$arg" in
    --no-push) push=0 ;;
    --no-scan) scan=0 ;;
    --claude) claude=1 ;;
    *) echo "usage: nix_update [--no-push] [--no-scan] [--claude]" >&2; exit 2 ;;
  esac
done

# Confirmed findings to SecObserve (infra2.0, ADR-0049) as CycloneDX, written
# by scan_system. The file name must stay: SecObserve keeps observations per
# file name. Only reachable at home; the token is encrypted to the OpenPGP key
# and asks for PIN and touch.
upload_findings() {
  local url=https://secobserve.think.do9ita.de
  local token="$HOME/.config/secobserve/upload-token.gpg"
  [ -f "$token" ] || { echo "==> no $token, skipping the upload"; return 0; }
  curl --fail --silent --max-time 5 --output /dev/null "$url/api/status/health/" \
    || { echo "==> SecObserve not reachable, skipping the upload"; return 0; }
  [ -s "$state/frame.vulnix.cdx.json" ] || { echo "==> no CycloneDX report, skipping the upload"; return 0; }
  gpg --quiet --decrypt "$token" | sed 's/^/Authorization: APIToken /' \
    | curl --fail --silent --show-error --max-time 300 \
      --header @- \
      --form "file=@$state/frame.vulnix.cdx.json" \
      --form product_name=host-frame \
      --form service=frame \
      --output /dev/null \
      "$url/api/import/file_upload_observations_by_name/"
  echo "==> confirmed findings uploaded to SecObserve"
}

# vulnxscan (sbomnix) runs vulnix, grype and OSV on the runtime closure and
# applies the whitelist from the repo (no rebuild needed for new entries).
# vulnxscan-report keeps only confirmed findings (vulnix or OSV, or two
# scanners agree), compares with the previous scan and writes the CycloneDX
# report for SecObserve. Results stay in $state for manual analysis.
scan_system() {
  local tmp rc=0
  mkdir -p "$state"
  [ -f "$state/vulns.csv" ] && mv "$state/vulns.csv" "$state/vulns.prev.csv"
  tmp=$(mktemp -d)
  # vulnxscan writes intermediate files into the working directory
  (cd "$tmp" && vulnxscan /run/current-system --whitelist "$whitelist" \
    --out "$state/vulns.csv") > "$state/vulnxscan.log" 2>&1 || rc=$?
  rm -rf "$tmp"
  [ "$rc" -eq 0 ] || return "$rc"
  python3 -I "$VULNXSCAN_REPORT" report "$state/vulns.csv" "$state/vulns.prev.csv" \
    "$state/frame.vulnix.cdx.json" frame
}

# --claude: pre-assessment of new confirmed findings with Claude Code (claude
# from PATH, account of the logged-in user). Annotations and whitelist
# candidates only, see vulnxscan-report.py. Environment:
# FRAME_UPDATE_CLAUDE_MODEL (sonnet), FRAME_UPDATE_CLAUDE_MAX (60 findings
# per run), FRAME_UPDATE_CLAUDE_BUDGET (1.00 USD, --max-budget-usd).
assess_findings() {
  if ! command -v claude > /dev/null 2>&1; then
    echo "==> claude not found, skipping the pre-assessment"
    return 0
  fi
  python3 -I "$VULNXSCAN_REPORT" assess "$state" \
    || echo "==> claude pre-assessment failed, the scan above stands" >&2
}

# Release switch hint (flake.nix, "Release switch"): reports a stable release
# with both nixpkgs nixos-YY.MM and Home Manager release-YY.MM branches that is
# not older than the running system (no hint for a downgrade from unstable).
release_hint() {
  local pinned running newest
  pinned=$(jq -r '.nodes[.nodes.root.inputs.nixpkgs].original.ref // "nixos-unstable"' flake.lock)
  running=$(cut -d. -f1,2 /run/current-system/nixos-version)
  newest=$(timeout 20 git ls-remote --heads https://github.com/NixOS/nixpkgs 'refs/heads/nixos-[0-9][0-9].[0-9][0-9]' \
    | sed 's|.*refs/heads/nixos-||' | sort -V | tail -n 1)
  [ -n "$newest" ] && [ "$pinned" != "nixos-$newest" ] || return 0
  [ "$(printf '%s\n' "$running" "$newest" | sort -V | head -n 1)" = "$running" ] || return 0
  timeout 20 git ls-remote --exit-code --heads https://github.com/nix-community/home-manager \
    "refs/heads/release-$newest" > /dev/null || return 0
  echo "==> NixOS $newest is branched (nixpkgs nixos-$newest, Home Manager release-$newest)," \
    "pinned is $pinned; see \"Release switch\" in flake.nix"
}

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

release_hint || true

if [ "$scan" -eq 1 ]; then
  echo "==> vulnxscan /run/current-system (vulnix, grype, OSV; takes a few minutes)"
  if scan_system; then
    upload_findings || echo "==> upload to SecObserve failed, the scan above stands" >&2
    if [ "$claude" -eq 1 ]; then assess_findings; fi
  else
    echo "==> vulnxscan failed, see $state/vulnxscan.log" >&2
  fi
fi

echo "==> user tools (flatpak, rustup, cargo/go/uv/krew) are covered by update_all"
