#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
INDEX_DIR="$ROOT_DIR/dists/stable/main/binary-amd64"
LOG_FILE="$LOG_DIR/generate-index.log"

mkdir -p "$LOG_DIR" "$INDEX_DIR"
: > "$LOG_FILE"

if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
  printf 'missing required tool: dpkg-scanpackages\n' | tee -a "$LOG_FILE" >&2
  exit 1
fi

if ! command -v gzip >/dev/null 2>&1; then
  printf 'missing required tool: gzip\n' | tee -a "$LOG_FILE" >&2
  exit 1
fi

cd "$ROOT_DIR"
dpkg-scanpackages pool /dev/null > "$INDEX_DIR/Packages" 2>> "$LOG_FILE"
gzip -9c "$INDEX_DIR/Packages" > "$INDEX_DIR/Packages.gz"

printf 'generated %s\n' "$INDEX_DIR/Packages" | tee -a "$LOG_FILE"
printf 'generated %s\n' "$INDEX_DIR/Packages.gz" | tee -a "$LOG_FILE"
