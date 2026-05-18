#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
INDEX_DIR="$ROOT_DIR/dists/stable/main/binary-amd64"
LOG_FILE="$LOG_DIR/test-local-repo.log"
TMP_DIR="$ROOT_DIR/tmp/test-local-repo"

mkdir -p "$LOG_DIR"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
: > "$LOG_FILE"

fail() {
  printf 'FAIL: %s\n' "$1" | tee -a "$LOG_FILE" >&2
  exit 1
}

assert_package_files() {
  local package="$1"
  local expected_file="$TMP_DIR/$package.expected"
  local actual_file="$TMP_DIR/$package.actual"
  local deb="$ROOT_DIR/pool/${package}_0.1.0_all.deb"

  shift
  printf '%s\n' "$@" | sort > "$expected_file"
  dpkg-deb --contents "$deb" \
    | awk '$1 ~ /^-/ {print $6}' \
    | sort > "$actual_file"

  if ! diff -u "$expected_file" "$actual_file" >> "$LOG_FILE" 2>&1; then
    fail "$package file manifest does not match expected contents"
  fi
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

for package in soryos-archive-keyring soryos-system-lock sory-shell sory-theme sory-settings sory-installer soryos-desktop; do
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

installer_contents="$TMP_DIR/sory-installer.contents"
system_lock_contents="$TMP_DIR/soryos-system-lock.contents"
dpkg-deb --contents "$ROOT_DIR/pool/sory-installer_0.1.0_all.deb" > "$installer_contents"
dpkg-deb --contents "$ROOT_DIR/pool/soryos-system-lock_0.1.0_all.deb" > "$system_lock_contents"

grep -q './usr/bin/soryos-install$' "$installer_contents" \
  || fail "sory-installer does not contain /usr/bin/soryos-install"
grep -q './usr/bin/soryos-repair$' "$installer_contents" \
  || fail "sory-installer does not contain /usr/bin/soryos-repair"
grep -q './usr/bin/soryos-diagnose$' "$installer_contents" \
  || fail "sory-installer does not contain /usr/bin/soryos-diagnose"
grep -q './usr/bin/soryos-safe-upgrade$' "$installer_contents" \
  || fail "sory-installer does not contain /usr/bin/soryos-safe-upgrade"
grep -q './usr/lib/soryos/apt-safe-install$' "$installer_contents" \
  || fail "sory-installer does not contain /usr/lib/soryos/apt-safe-install"
grep -q './usr/share/soryos/apt/soryos.pref$' "$installer_contents" \
  || fail "sory-installer does not contain packaged SoryOS preferences"
grep -q './etc/apt/preferences.d/soryos.pref$' "$system_lock_contents" \
  || fail "soryos-system-lock does not contain APT preferences"

for package in soryos-archive-keyring soryos-system-lock sory-shell sory-theme sory-settings sory-installer soryos-desktop; do
  deb="$ROOT_DIR/pool/${package}_0.1.0_all.deb"
  contents="$TMP_DIR/$package.contents"
  dpkg-deb --contents "$deb" > "$contents"
  grep -q "./usr/share/soryos/modules/$package$" "$contents" \
    || fail "$package does not contain its SoryOS module marker"
done

assert_package_files soryos-archive-keyring \
  ./usr/share/doc/soryos-archive-keyring/README \
  ./usr/share/keyrings/soryos-archive-keyring.gpg \
  ./usr/share/soryos/modules/soryos-archive-keyring

assert_package_files soryos-system-lock \
  ./etc/apt/preferences.d/soryos.pref \
  ./usr/bin/soryos-apply-holds \
  ./usr/bin/soryos-remove-holds \
  ./usr/share/doc/soryos-system-lock/README \
  ./usr/share/soryos/modules/soryos-system-lock

assert_package_files sory-shell \
  ./usr/share/doc/sory-shell/README \
  ./usr/share/soryos/modules/sory-shell

assert_package_files sory-theme \
  ./usr/share/doc/sory-theme/README \
  ./usr/share/soryos/modules/sory-theme

assert_package_files sory-settings \
  ./usr/share/doc/sory-settings/README \
  ./usr/share/soryos/modules/sory-settings

assert_package_files sory-installer \
  ./usr/bin/soryos-diagnose \
  ./usr/bin/soryos-install \
  ./usr/bin/soryos-install-base \
  ./usr/bin/soryos-repair \
  ./usr/bin/soryos-safe-upgrade \
  ./usr/lib/soryos/apt-safe-install \
  ./usr/share/doc/sory-installer/README \
  ./usr/share/soryos/apt/soryos.pref \
  ./usr/share/soryos/modules/sory-installer

assert_package_files soryos-desktop \
  ./usr/share/doc/soryos-desktop/README \
  ./usr/share/soryos/modules/soryos-desktop

printf 'local repository test complete\n' | tee -a "$LOG_FILE"
