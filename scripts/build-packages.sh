#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
POOL_DIR="$ROOT_DIR/pool"
PKG_DIR="$ROOT_DIR/packages"
TMP_DIR="$ROOT_DIR/tmp/build"
LOG_FILE="$LOG_DIR/build-packages.log"

mkdir -p "$LOG_DIR" "$POOL_DIR" "$TMP_DIR"
: > "$LOG_FILE"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing required tool: %s\n' "$1" | tee -a "$LOG_FILE" >&2
    exit 1
  fi
}

require_tool dpkg-deb

build_package() {
  local name="$1"
  local control_file="$PKG_DIR/$name/control"
  local work_dir="$TMP_DIR/$name"
  local payload_dir="$PKG_DIR/$name/root"
  local doc_dir="$work_dir/usr/share/doc/$name"
  local marker_dir="$work_dir/usr/share/soryos/modules"
  local version
  local arch
  local deb

  if [[ ! -f "$control_file" ]]; then
    printf 'missing control file: %s\n' "$control_file" | tee -a "$LOG_FILE" >&2
    exit 1
  fi

  version="$(awk '/^Version: / {print $2}' "$control_file")"
  arch="$(awk '/^Architecture: / {print $2}' "$control_file")"
  deb="$POOL_DIR/${name}_${version}_${arch}.deb"

  rm -rf "$work_dir"
  mkdir -p "$work_dir/DEBIAN" "$doc_dir" "$marker_dir"
  cp "$control_file" "$work_dir/DEBIAN/control"

  if [[ -d "$payload_dir" ]]; then
    cp -a "$payload_dir"/. "$work_dir"/
  fi

  if [[ "$name" == "soryos-archive-keyring" ]]; then
    if [[ ! -f "$ROOT_DIR/keyrings/soryos-archive-keyring.gpg" ]]; then
      printf 'missing keyring for %s: run ./scripts/init-signing-key.sh first\n' "$name" | tee -a "$LOG_FILE" >&2
      exit 1
    fi
    mkdir -p "$work_dir/usr/share/keyrings"
    cp "$ROOT_DIR/keyrings/soryos-archive-keyring.gpg" "$work_dir/usr/share/keyrings/soryos-archive-keyring.gpg"
  fi

  cat > "$doc_dir/README" <<EOF
$name is a SoryOS migration marker package.

It is intentionally minimal and reversible.
It does not replace Pop!_OS packages yet.
EOF

  printf '%s\n' "$name" > "$marker_dir/$name"
  chmod -R go-w "$work_dir"
  find "$work_dir/usr/bin" -type f -exec chmod 0755 {} + 2>/dev/null || true

  dpkg-deb --build "$work_dir" "$deb" >> "$LOG_FILE" 2>&1
  printf 'built %s\n' "$deb" | tee -a "$LOG_FILE"
}

rm -f "$POOL_DIR"/*.deb

build_package soryos-archive-keyring
build_package sory-shell
build_package sory-theme
build_package sory-settings
build_package sory-installer

printf 'package build complete\n' | tee -a "$LOG_FILE"
