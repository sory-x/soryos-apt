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
[[ -f "$ROOT_DIR/dists/stable/Release" ]] || fail "missing Release file"
[[ -f "$ROOT_DIR/dists/stable/Release.gpg" ]] || fail "missing Release.gpg file"
[[ -f "$ROOT_DIR/dists/stable/InRelease" ]] || fail "missing InRelease file"

gzip -t "$INDEX_DIR/Packages.gz" || fail "Packages.gz is not valid gzip"
gpgv --keyring "$ROOT_DIR/keyrings/soryos-archive-keyring.gpg" \
  "$ROOT_DIR/dists/stable/Release.gpg" "$ROOT_DIR/dists/stable/Release" >/dev/null 2>&1 \
  || fail "Release.gpg signature is invalid"
gpgv --keyring "$ROOT_DIR/keyrings/soryos-archive-keyring.gpg" \
  "$ROOT_DIR/dists/stable/InRelease" >/dev/null 2>&1 \
  || fail "InRelease signature is invalid"

for package in soryos-archive-keyring sory-shell sory-theme sory-settings sory-installer soryos-desktop; do
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
