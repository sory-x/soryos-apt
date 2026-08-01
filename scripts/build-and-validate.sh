#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/build-and-validate.log"
OUTPUT_DIR="$ROOT_DIR/tmp/repo-validate-$(id -u)"
TARGET="${SORYOS_TARGET:-x86_64-unknown-redox}"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

cd "$ROOT_DIR"
SORYOS_PKGAR_OUTPUT="$OUTPUT_DIR" ./scripts/build-packages.sh | tee -a "$LOG_FILE"

printf 'validating pkgar repository structure\n' | tee -a "$LOG_FILE"
test -f "$OUTPUT_DIR/$TARGET/repo.toml"
test -f "$OUTPUT_DIR/id_ed25519.pub.toml"
test -n "$(ls "$OUTPUT_DIR/$TARGET"/*.pkgar 2>/dev/null | head -1)"

printf 'build and validation complete: %s packages\n' \
  "$(ls "$OUTPUT_DIR/$TARGET"/*.pkgar 2>/dev/null | wc -l)" | tee -a "$LOG_FILE"
