#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rm -rf "$ROOT_DIR/tmp"
rm -f "$ROOT_DIR"/pool/main/*.deb
rm -f "$ROOT_DIR/dists/stable/main/binary-amd64/Packages"
rm -f "$ROOT_DIR/dists/stable/main/binary-amd64/Packages.gz"

printf 'local generated packages and indexes removed\n'
