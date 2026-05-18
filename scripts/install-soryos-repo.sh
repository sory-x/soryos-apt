#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${SORYOS_REPO_URL:-https://sory-x.github.io/soryos-apt}"
KEY_URL="$REPO_URL/keyrings/soryos-archive-keyring.gpg"
KEYRING_PATH="/usr/share/keyrings/soryos-archive-keyring.gpg"
SOURCE_PATH="/etc/apt/sources.list.d/soryos.list"
PACKAGES=(soryos-archive-keyring soryos-system-lock sory-shell sory-theme sory-settings sory-installer soryos-desktop)
PREFERENCES_PATH="/etc/apt/preferences.d/soryos.pref"

if [[ "${EUID}" -ne 0 ]]; then
  printf 'run as root: sudo %s\n' "$0" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  printf 'missing required tool: curl\n' >&2
  exit 1
fi

install -d -m 0755 /usr/share/keyrings /etc/apt/sources.list.d
install -d -m 0755 /etc/apt/preferences.d
curl -fsSL "$KEY_URL" -o "$KEYRING_PATH"
chmod 0644 "$KEYRING_PATH"

cat > "$SOURCE_PATH" <<EOF
deb [signed-by=$KEYRING_PATH] $REPO_URL stable main
EOF

cat > "$PREFERENCES_PATH" <<'EOF'
Package: sory* soryos-*
Pin: release o=SoryOS
Pin-Priority: 700

Package: *
Pin: release o=SoryOS
Pin-Priority: 100
EOF

apt-get update
apt-get install -y "${PACKAGES[@]}"

printf 'SoryOS repository installed from %s\n' "$REPO_URL"
printf 'Rollback: sudo rm -f %s %s %s && sudo apt update\n' "$SOURCE_PATH" "$PREFERENCES_PATH" "$KEYRING_PATH"
