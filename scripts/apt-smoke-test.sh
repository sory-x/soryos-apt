#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
TMP_DIR="$ROOT_DIR/tmp/apt-smoke"
LOG_FILE="$LOG_DIR/apt-smoke-test.log"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

if ! command -v apt-get >/dev/null 2>&1; then
  printf 'missing required tool: apt-get\n' | tee -a "$LOG_FILE" >&2
  exit 1
fi

rm -rf "$TMP_DIR"
mkdir -p \
  "$TMP_DIR/etc/apt" \
  "$TMP_DIR/etc/apt/preferences.d" \
  "$TMP_DIR/var/lib/apt/lists/partial" \
  "$TMP_DIR/var/cache/apt/archives/partial" \
  "$TMP_DIR/var/lib/dpkg"

touch "$TMP_DIR/var/lib/dpkg/status"

cat > "$TMP_DIR/etc/apt/sources.list" <<EOF
deb [trusted=yes] file:$ROOT_DIR stable main
EOF

apt-get \
  -o APT::Architectures::=amd64 \
  -o Dir="$TMP_DIR" \
  -o Dir::Etc::sourcelist="$TMP_DIR/etc/apt/sources.list" \
  -o Dir::Etc::sourceparts="-" \
  -o Dir::Etc::main="-" \
  -o Dir::State::status="$TMP_DIR/var/lib/dpkg/status" \
  -o Debug::NoLocking=1 \
  update >> "$LOG_FILE" 2>&1

apt-cache \
  -o APT::Architectures::=amd64 \
  -o Dir="$TMP_DIR" \
  -o Dir::Etc::sourcelist="$TMP_DIR/etc/apt/sources.list" \
  -o Dir::Etc::sourceparts="-" \
  -o Dir::Etc::main="-" \
  -o Dir::State::status="$TMP_DIR/var/lib/dpkg/status" \
  policy soryos-archive-keyring soryos-system-lock sory-shell sory-theme sory-settings sory-installer soryos-desktop >> "$LOG_FILE" 2>&1

printf 'isolated apt smoke test complete\n' | tee -a "$LOG_FILE"
