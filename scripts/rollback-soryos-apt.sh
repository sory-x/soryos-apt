#!/usr/bin/env bash
set -euo pipefail

SOURCE_PATH="/etc/apt/sources.list.d/soryos.list"
PREFERENCES_PATH="/etc/apt/preferences.d/soryos.pref"
KEYRING_PATH="/usr/share/keyrings/soryos-archive-keyring.gpg"

if [[ "${EUID}" -ne 0 ]]; then
  printf 'run as root: sudo %s\n' "$0" >&2
  exit 1
fi

rm -f "$SOURCE_PATH" "$PREFERENCES_PATH" "$KEYRING_PATH"
apt-get update

printf 'SoryOS APT source and keyring removed.\n'
printf 'Installed SoryOS packages were left untouched. Remove them manually only if needed.\n'
