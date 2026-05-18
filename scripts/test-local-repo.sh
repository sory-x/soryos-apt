#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
INDEX_DIR="$ROOT_DIR/dists/stable/main/binary-amd64"
LOG_FILE="$LOG_DIR/test-local-repo.log"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

fail() {
  printf 'FAIL: %s\n' "$1" | tee -a "$LOG_FILE" >&2
  exit 1
}

[[ -f "$INDEX_DIR/Packages" ]] || fail "missing Packages index"
[[ -f "$INDEX_DIR/Packages.gz" ]] || fail "missing Packages.gz index"

gzip -t "$INDEX_DIR/Packages.gz" || fail "Packages.gz is not valid gzip"

for package in sory-shell sory-theme sory-settings sory-installer; do
  if ! grep -q "^Package: $package$" "$INDEX_DIR/Packages"; then
    fail "missing package in index: $package"
  fi
  printf 'found package: %s\n' "$package" | tee -a "$LOG_FILE"
done

shopt -s nullglob
debs=("$ROOT_DIR"/pool/*.deb)
[[ ${#debs[@]} -gt 0 ]] || fail "missing deb files in pool/"

for deb in "${debs[@]}"; do
  dpkg-deb --info "$deb" >/dev/null || fail "invalid deb: $deb"
  printf 'valid deb: %s\n' "$deb" | tee -a "$LOG_FILE"
done

printf 'local repository test complete\n' | tee -a "$LOG_FILE"
