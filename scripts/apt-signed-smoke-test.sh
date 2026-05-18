#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${1:-file:$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
TMP_DIR="$ROOT_DIR/tmp/apt-signed-smoke"
KEYRING="$ROOT_DIR/keyrings/soryos-archive-keyring.gpg"
LOG_FILE="$LOG_DIR/apt-signed-smoke-test.log"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

if ! command -v apt-get >/dev/null 2>&1; then
  printf 'missing required tool: apt-get\n' | tee -a "$LOG_FILE" >&2
  exit 1
fi

if [[ ! -f "$KEYRING" ]]; then
  printf 'missing public keyring: %s\nrun ./scripts/init-signing-key.sh first\n' "$KEYRING" | tee -a "$LOG_FILE" >&2
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
deb [signed-by=$KEYRING] $REPO_URL stable main
EOF

cp "$ROOT_DIR/config/apt/preferences.d/soryos.pref" "$TMP_DIR/etc/apt/preferences.d/soryos.pref"

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

apt-get \
  -s \
  -o APT::Architectures::=amd64 \
  -o Dir="$TMP_DIR" \
  -o Dir::Etc::sourcelist="$TMP_DIR/etc/apt/sources.list" \
  -o Dir::Etc::sourceparts="-" \
  -o Dir::Etc::main="-" \
  -o Dir::State::status="$TMP_DIR/var/lib/dpkg/status" \
  -o Debug::NoLocking=1 \
  install soryos-desktop >> "$LOG_FILE" 2>&1

if grep -Eq '^[0-9]+ upgraded, [0-9]+ newly installed, [1-9][0-9]* to remove' "$LOG_FILE"; then
  printf 'FAIL: simulated install would remove packages\n' | tee -a "$LOG_FILE" >&2
  exit 1
fi

printf 'isolated signed apt smoke test complete for %s\n' "$REPO_URL" | tee -a "$LOG_FILE"
