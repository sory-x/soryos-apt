#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/ci-local.log"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

cd "$ROOT_DIR"

printf 'CI: syntax checks\n' | tee -a "$LOG_FILE"
bash -n scripts/*.sh

printf 'CI: build and pkgar validation\n' | tee -a "$LOG_FILE"
./scripts/build-and-validate.sh | tee -a "$LOG_FILE"

printf 'CI complete\n' | tee -a "$LOG_FILE"
