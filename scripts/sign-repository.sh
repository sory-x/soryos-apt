#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/sign-repository.log"
GNUPGHOME_DIR="${SORYOS_GNUPGHOME:-$ROOT_DIR/.private/gnupg}"
KEY_EMAIL="${SORYOS_APT_KEY_EMAIL:-apt@soryos.local}"
SUITES="${SORYOS_SUITES:-stable testing nightly}"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

if ! command -v apt-ftparchive >/dev/null 2>&1; then
  printf 'missing required tool: apt-ftparchive\n' | tee -a "$LOG_FILE" >&2
  exit 1
fi

if ! command -v gpg >/dev/null 2>&1; then
  printf 'missing required tool: gpg\n' | tee -a "$LOG_FILE" >&2
  exit 1
fi

if [[ ! -d "$GNUPGHOME_DIR" ]]; then
  printf 'missing signing GNUPGHOME: %s\nrun ./scripts/init-signing-key.sh first\n' "$GNUPGHOME_DIR" | tee -a "$LOG_FILE" >&2
  exit 1
fi

export GNUPGHOME="$GNUPGHOME_DIR"

cd "$ROOT_DIR"
SORYOS_SUITES="$SUITES" ./scripts/generate-index.sh >> "$LOG_FILE" 2>&1

for suite in $SUITES; do
  DIST_DIR="$ROOT_DIR/dists/$suite"

  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin="SoryOS" \
    -o APT::FTPArchive::Release::Label="SoryOS" \
    -o APT::FTPArchive::Release::Suite="$suite" \
    -o APT::FTPArchive::Release::Codename="$suite" \
    -o APT::FTPArchive::Release::Architectures="amd64" \
    -o APT::FTPArchive::Release::Components="main" \
    -o APT::FTPArchive::Release::Description="SoryOS APT Repository" \
    release "$DIST_DIR" > "$DIST_DIR/Release"

  gpg --batch --yes --local-user "$KEY_EMAIL" --detach-sign --armor \
    -o "$DIST_DIR/Release.gpg" "$DIST_DIR/Release"

  gpg --batch --yes --local-user "$KEY_EMAIL" --clearsign \
    -o "$DIST_DIR/InRelease" "$DIST_DIR/Release"

  printf 'generated %s\n' "$DIST_DIR/Release" | tee -a "$LOG_FILE"
  printf 'generated %s\n' "$DIST_DIR/Release.gpg" | tee -a "$LOG_FILE"
  printf 'generated %s\n' "$DIST_DIR/InRelease" | tee -a "$LOG_FILE"
done
