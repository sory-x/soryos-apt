#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${SORYOS_REPO_URL:-https://sory-x.github.io/soryos-apt}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_URL="$REPO_URL/keyrings/soryos-archive-keyring.gpg"
KEYRING_PATH="/usr/share/keyrings/soryos-archive-keyring.gpg"
SOURCE_PATH="/etc/apt/sources.list.d/soryos.list"
PREFERENCES_PATH="/etc/apt/preferences.d/soryos.pref"
BACKUP_DIR="/var/backups/soryos-apt/$(date +%Y%m%d%H%M%S)"

if [[ "${EUID}" -ne 0 ]]; then
  printf 'run as root: sudo %s\n' "$0" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  printf 'missing required tool: curl\n' >&2
  exit 1
fi

install -d -m 0755 /usr/share/keyrings /etc/apt/sources.list.d /etc/apt/preferences.d "$BACKUP_DIR"

for path in "$KEYRING_PATH" "$SOURCE_PATH" "$PREFERENCES_PATH"; do
  if [[ -e "$path" ]]; then
    cp -a "$path" "$BACKUP_DIR/$(basename "$path")"
  fi
done

curl -fsSL "$KEY_URL" -o "$KEYRING_PATH"
chmod 0644 "$KEYRING_PATH"

cat > "$SOURCE_PATH" <<EOF
deb [signed-by=$KEYRING_PATH] $REPO_URL stable main
EOF

cp "$ROOT_DIR/config/apt/preferences.d/soryos.pref" "$PREFERENCES_PATH"

apt-get update

printf 'SoryOS APT source configured as secondary repository.\n'
printf 'Backups stored under: %s\n' "$BACKUP_DIR"
printf 'No Pop!_OS repositories were removed.\n'
