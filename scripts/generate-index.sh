#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/generate-index.log"
SUITES="${SORYOS_SUITES:-stable testing nightly}"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
  printf 'missing required tool: dpkg-scanpackages\n' | tee -a "$LOG_FILE" >&2
  exit 1
fi

if ! command -v gzip >/dev/null 2>&1; then
  printf 'missing required tool: gzip\n' | tee -a "$LOG_FILE" >&2
  exit 1
fi

for suite in $SUITES; do
  INDEX_DIR="$ROOT_DIR/dists/$suite/main/binary-amd64"
  mkdir -p "$INDEX_DIR"

  cd "$ROOT_DIR"
  dpkg-scanpackages pool /dev/null > "$INDEX_DIR/Packages" 2>> "$LOG_FILE"
  gzip -9cn "$INDEX_DIR/Packages" > "$INDEX_DIR/Packages.gz"

  printf 'generated %s\n' "$INDEX_DIR/Packages" | tee -a "$LOG_FILE"
  printf 'generated %s\n' "$INDEX_DIR/Packages.gz" | tee -a "$LOG_FILE"
done
