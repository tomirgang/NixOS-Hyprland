# update-all: complete update routine of host frame (alias update_all).
#   1. flatpak update (Logseq fallback)
#   2. rustup update
#   3. all cargo crates from `cargo install --list` (crates.io and git sources)
#   4. garminctl via go install @latest
#   5. uv tool upgrade --all
#   6. kubectl krew upgrade
#   7. frame-update (alias nix_update), options are passed on unchanged
# A failed step is reported and does not stop the following steps; the exit
# code is 1 if any step failed. Missing tools are skipped with a notice.
# writeShellApplication enables errexit; failures are collected by step instead.
set +e -uo pipefail

failed=()

step() {
  local name="$1"
  shift
  echo "==> $name"
  if ! "$@"; then
    echo "==> $name failed" >&2
    failed+=("$name")
  fi
}

have() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  fi
  echo "==> $1 not found, skipped"
  return 1
}

# cargo install reinstalls a crate only if a newer version (crates.io) or a
# newer commit (git) exists, so unchanged crates are not rebuilt.
cargo_update_all() {
  local line name src rc=0
  local re='\(([^)]*)\):$'
  while IFS= read -r line; do
    case "$line" in "" | " "*) continue ;; esac
    name="${line%% *}"
    src=""
    if [[ "$line" =~ $re ]]; then
      src="${BASH_REMATCH[1]}"
    fi
    case "$src" in
      "")
        echo "--> $name (crates.io)"
        cargo install --locked "$name" || rc=1
        ;;
      http* | git*)
        echo "--> $name (git ${src%%#*})"
        cargo install --locked --git "${src%%#*}" "$name" || rc=1
        ;;
      *)
        echo "--> $name: source '$src' not handled, skipped"
        ;;
    esac
  done < <(cargo install --list)
  return "$rc"
}

if have flatpak; then step "flatpak update" flatpak update -y; fi
if have rustup; then step "rustup update" rustup update; fi
if have cargo; then step "cargo crates" cargo_update_all; fi
if have go; then
  step "garminctl" go install github.com/jjuanrivvera/garminctl/cmd/garminctl@latest
fi
if have uv; then step "uv tools" uv tool upgrade --all; fi
if have kubectl-krew; then step "krew plugins" kubectl krew upgrade; fi

step "nix_update" frame-update "$@"

if [ "${#failed[@]}" -gt 0 ]; then
  echo "==> failed steps: ${failed[*]}" >&2
  exit 1
fi
echo "==> all updates done"
