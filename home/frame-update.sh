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

# vulnix findings to SecObserve (infra2.0, ADR-0049). SecObserve has no parser for
# vulnix, so the report becomes CycloneDX. The file name must stay: SecObserve
# keeps observations per file name. Only reachable at home; the token is
# encrypted to the OpenPGP key and asks for PIN and touch.
upload_findings() {
  local url=https://secobserve.think.do9ita.de
  local token="$HOME/.config/secobserve/upload-token.gpg"
  local dir
  [ -f "$token" ] || { echo "==> no $token, skipping the upload"; return 0; }
  curl --fail --silent --max-time 5 --output /dev/null "$url/api/status/health/" \
    || { echo "==> SecObserve not reachable, skipping the upload"; return 0; }
  dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN
  vulnix --system --json > "$dir/vulnix.json" || true
  jq '
    def severity: if . >= 9 then "critical" elif . >= 7 then "high"
      elif . >= 4 then "medium" elif . > 0 then "low" else "unknown" end;
    {
      bomFormat: "CycloneDX",
      specVersion: "1.6",
      version: 1,
      metadata: {
        tools: {components: [{type: "application", name: "vulnix"}]},
        component: {type: "operating-system", name: "frame"}
      },
      # Several derivations can share a name; bom-ref must be unique.
      components: (unique_by(.name) | map({
        type: "library",
        "bom-ref": .name,
        name: .pname,
        version: .version,
        purl: "pkg:nix/\(.pname)@\(.version)"
      })),
      vulnerabilities: [unique_by(.name)[] | . as $p | .affected_by[] | . as $id | {
        id: $id,
        description: ($p.description[$id] // ""),
        ratings: (if $p.cvssv3_basescore[$id] then [{
          method: "CVSSv31",
          score: $p.cvssv3_basescore[$id],
          severity: ($p.cvssv3_basescore[$id] | severity)
        }] else [] end),
        affects: [{ref: $p.name}]
      }]
    }' "$dir/vulnix.json" > "$dir/frame.vulnix.cdx.json"
  gpg --quiet --decrypt "$token" | sed 's/^/Authorization: APIToken /' \
    | curl --fail --silent --show-error --max-time 300 \
      --header @- \
      --form "file=@$dir/frame.vulnix.cdx.json" \
      --form product_name=host-frame \
      --form service=frame \
      --output /dev/null \
      "$url/api/import/file_upload_observations_by_name/"
  echo "==> vulnix findings uploaded to SecObserve"
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

if [ "$scan" -eq 1 ]; then
  echo "==> vulnix --system (known CVEs of the running system)"
  # Findings set a non-zero exit code; the scan is a report, not a failure
  vulnix --system || echo "==> vulnix exit code $?: findings above (or scan error)"
  upload_findings || echo "==> upload to SecObserve failed, the scan above stands" >&2
fi

echo "==> user tools (flatpak, rustup, cargo/go/uv/krew) are covered by update_all"
