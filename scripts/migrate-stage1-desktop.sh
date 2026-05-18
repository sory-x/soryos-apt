#!/usr/bin/env bash
set -euo pipefail

PACKAGES=(soryos-archive-keyring soryos-system-lock sory-shell sory-theme sory-settings sory-installer soryos-desktop)

if [[ "${EUID}" -ne 0 ]]; then
  printf 'run as root: sudo %s\n' "$0" >&2
  exit 1
fi

apt-get update
apt-cache policy "${PACKAGES[@]}"
apt-get install -y "${PACKAGES[@]}"

printf 'SoryOS stage 1 desktop modules installed.\n'
printf 'No Pop!_OS packages were removed by this script.\n'
printf 'Rollback packages only: sudo apt remove soryos-desktop sory-installer sory-settings sory-theme sory-shell\n'
