#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    printf 'usage: %s INDEX.json PRIVATE_KEY.pem\n' "$0" >&2
    exit 2
fi

index=$1
private_key=$2
signature="${index}.sig"

[[ -s "$index" ]] || { echo "missing index: $index" >&2; exit 1; }
[[ -s "$private_key" ]] || { echo "missing signing key" >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "openssl is required" >&2; exit 1; }

temporary="${signature}.tmp"
openssl pkeyutl -sign -rawin -inkey "$private_key" -in "$index" -out "$temporary"
mv "$temporary" "$signature"
chmod 0644 "$signature"
printf 'signed %s -> %s\n' "$index" "$signature"
