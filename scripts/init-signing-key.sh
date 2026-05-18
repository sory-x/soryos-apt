#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GNUPGHOME_DIR="${SORYOS_GNUPGHOME:-$ROOT_DIR/.private/gnupg}"
KEY_NAME="${SORYOS_APT_KEY_NAME:-SoryOS APT Repository}"
KEY_EMAIL="${SORYOS_APT_KEY_EMAIL:-apt@soryos.local}"
KEYRING_DIR="$ROOT_DIR/keyrings"

mkdir -p "$GNUPGHOME_DIR" "$KEYRING_DIR"
chmod 700 "$GNUPGHOME_DIR"

export GNUPGHOME="$GNUPGHOME_DIR"

if ! gpg --batch --list-secret-keys "$KEY_EMAIL" >/dev/null 2>&1; then
  cat > "$ROOT_DIR/tmp-gpg-key.conf" <<EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: $KEY_NAME
Name-Email: $KEY_EMAIL
Expire-Date: 0
%no-protection
%commit
EOF
  gpg --batch --generate-key "$ROOT_DIR/tmp-gpg-key.conf"
  rm -f "$ROOT_DIR/tmp-gpg-key.conf"
fi

KEY_FPR="$(gpg --batch --with-colons --list-secret-keys "$KEY_EMAIL" | awk -F: '/^fpr:/ {print $10; exit}')"
if [[ -z "$KEY_FPR" ]]; then
  printf 'failed to determine signing key fingerprint\n' >&2
  exit 1
fi

gpg --batch --armor --export "$KEY_FPR" > "$KEYRING_DIR/soryos-archive-keyring.asc"
gpg --batch --export "$KEY_FPR" > "$KEYRING_DIR/soryos-archive-keyring.gpg"

cat > "$KEYRING_DIR/FINGERPRINT" <<EOF
$KEY_FPR
EOF

printf 'SoryOS APT signing key ready: %s\n' "$KEY_FPR"
printf 'Private key location: %s\n' "$GNUPGHOME_DIR"
printf 'Public key exported under: %s\n' "$KEYRING_DIR"
