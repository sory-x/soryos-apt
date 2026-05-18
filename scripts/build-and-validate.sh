#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
BACKUP_DIR="$ROOT_DIR/tmp/repo-rollback"
LOG_FILE="$LOG_DIR/build-and-validate.log"

mkdir -p "$LOG_DIR" "$ROOT_DIR/tmp"
: > "$LOG_FILE"

restore_repo() {
  if [[ -d "$BACKUP_DIR" ]]; then
    rm -rf "$ROOT_DIR/pool" "$ROOT_DIR/dists"
    cp -a "$BACKUP_DIR/pool" "$ROOT_DIR/pool"
    cp -a "$BACKUP_DIR/dists" "$ROOT_DIR/dists"
    printf 'repository rollback restored previous pool and dists\n' | tee -a "$LOG_FILE" >&2
  fi
}

trap 'restore_repo' ERR

rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -a "$ROOT_DIR/pool" "$BACKUP_DIR/pool"
cp -a "$ROOT_DIR/dists" "$BACKUP_DIR/dists"

cd "$ROOT_DIR"
./scripts/build-packages.sh | tee -a "$LOG_FILE"
./scripts/sign-repository.sh | tee -a "$LOG_FILE"
./scripts/test-local-repo.sh | tee -a "$LOG_FILE"

for suite in stable testing nightly; do
  ./scripts/validate-apt-safety.sh "file:$ROOT_DIR" "$suite" | tee -a "$LOG_FILE"
done

rm -rf "$BACKUP_DIR"
trap - ERR
printf 'build and validation complete\n' | tee -a "$LOG_FILE"
