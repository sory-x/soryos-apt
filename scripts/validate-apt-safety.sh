#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${1:-file:$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SUITE="${2:-stable}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
TMP_DIR="$ROOT_DIR/tmp/apt-safety-$SUITE"
KEYRING="$ROOT_DIR/keyrings/soryos-archive-keyring.gpg"
LOG_FILE="$LOG_DIR/validate-apt-safety-$SUITE.log"
PACKAGES=(soryos-archive-keyring soryos-system-lock sory-shell sory-theme sory-settings sory-installer soryos-desktop)

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

fail() {
  printf 'FAIL: %s\n' "$1" | tee -a "$LOG_FILE" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required tool: $1"
}

require_tool apt-get
require_tool apt-cache
require_tool dpkg-deb

[[ -f "$KEYRING" ]] || fail "missing public keyring: $KEYRING"

rm -rf "$TMP_DIR"
mkdir -p \
  "$TMP_DIR/etc/apt/preferences.d" \
  "$TMP_DIR/var/lib/apt/lists/partial" \
  "$TMP_DIR/var/cache/apt/archives/partial" \
  "$TMP_DIR/var/lib/dpkg"

touch "$TMP_DIR/var/lib/dpkg/status"

cat > "$TMP_DIR/etc/apt/sources.list" <<EOF
deb [signed-by=$KEYRING] $REPO_URL $SUITE main
EOF

cp "$ROOT_DIR/config/apt/preferences.d/soryos.pref" "$TMP_DIR/etc/apt/preferences.d/soryos.pref"

APT_OPTS=(
  -o APT::Architectures::=amd64
  -o Dir="$TMP_DIR"
  -o Dir::Etc::sourcelist="$TMP_DIR/etc/apt/sources.list"
  -o Dir::Etc::sourceparts="-"
  -o Dir::Etc::main="-"
  -o Dir::State::status="$TMP_DIR/var/lib/dpkg/status"
  -o Debug::NoLocking=1
)

apt-get "${APT_OPTS[@]}" update >> "$LOG_FILE" 2>&1

apt-cache "${APT_OPTS[@]}" policy "${PACKAGES[@]}" >> "$LOG_FILE" 2>&1

for package in "${PACKAGES[@]}"; do
  apt-cache "${APT_OPTS[@]}" show "$package" >> "$LOG_FILE" 2>&1 \
    || fail "package not resolvable: $package"
done

apt-get -s "${APT_OPTS[@]}" install soryos-desktop >> "$LOG_FILE" 2>&1 \
  || fail "apt simulation failed for soryos-desktop"

if grep -Eq '^(Remv|Purg) ' "$LOG_FILE"; then
  fail "simulated transaction contains removals or purges"
fi

if grep -Eiq '(broken packages|unmet dependencies|held broken|conflicts with|but it is not going to be installed)' "$LOG_FILE"; then
  fail "apt reported broken dependencies or conflicts"
fi

if grep -Eq '^[0-9]+ upgraded, [0-9]+ newly installed, [1-9][0-9]* to remove' "$LOG_FILE"; then
  fail "simulated transaction would remove packages"
fi

printf 'APT safety validation complete for %s %s\n' "$REPO_URL" "$SUITE" | tee -a "$LOG_FILE"
