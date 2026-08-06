#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    printf 'usage: %s INDEX.json INDEX.json.sig PUBLIC_KEY.pem\n' "$0" >&2
    exit 2
fi

index=$1
signature=$2
public_key=$3
[[ -s "$index" && -s "$signature" && -s "$public_key" ]] || {
    echo "index, signature and public key are required" >&2
    exit 1
}
command -v openssl >/dev/null 2>&1 || { echo "openssl is required" >&2; exit 1; }
openssl pkeyutl -verify -rawin -pubin -inkey "$public_key" \
    -in "$index" -sigfile "$signature"
