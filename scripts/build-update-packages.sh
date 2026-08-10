#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# SoryOS - Rebuild ONLY the changed recipes from source and prepare their
# .pkgar/.toml for an in-place update of an existing SoryOS Release.
# =============================================================================
# Unlike build-packages.sh, this script does NOT touch the full recipe set:
# the filesystem config is generated with only the given recipes set to
# rule="source". Every other package of the Release is left untouched.
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/update-packages.log"
WORK_DIR="${SORYOS_PKGAR_WORK:-$ROOT_DIR/tmp/build-$(id -u)}"

REDOX_REPO="${SORYOS_REDOX_REPO:-https://github.com/sory-x/Redox.git}"
REDOX_REF="${SORYOS_REDOX_REF:-main}"
TARGET="${SORYOS_TARGET:-x86_64-unknown-redox}"
OUTPUT_DIR="${SORYOS_PKGAR_OUTPUT:-$ROOT_DIR/repo-out}"
RECIPES="${SORYOS_RECIPES:-}"
MAKE_JOBS="${SORYOS_MAKE_JOBS:-$(nproc 2>/dev/null || echo 2)}"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

if [[ -z "$RECIPES" ]]; then
  printf 'SORYOS_RECIPES is required (space-separated recipe names)\n' >&2
  exit 1
fi

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing required tool: %s\n' "$1" | tee -a "$LOG_FILE" >&2
    exit 1
  fi
}

require_tool git
require_tool make
require_tool cargo
require_tool rustc
require_tool rustup

# ----------------------------------------------------------------------------
# 1. Clone the cookbook at the configured ref
# ----------------------------------------------------------------------------
if [[ -d "$WORK_DIR/redox/.git" ]]; then
  git -C "$WORK_DIR/redox" fetch origin >> "$LOG_FILE" 2>&1
  git -C "$WORK_DIR/redox" checkout "$REDOX_REF" >> "$LOG_FILE" 2>&1
  git -C "$WORK_DIR/redox" reset --hard "origin/$REDOX_REF" >> "$LOG_FILE" 2>&1
else
  mkdir -p "$WORK_DIR"
  git clone --depth 1 --branch "$REDOX_REF" "$REDOX_REPO" "$WORK_DIR/redox" >> "$LOG_FILE" 2>&1
fi

cd "$WORK_DIR/redox"

# ----------------------------------------------------------------------------
# 2. Minimal filesystem config: rebuild ONLY the given recipes from source
# ----------------------------------------------------------------------------
UPDATE_CONFIG="$WORK_DIR/redox/config/soryos-ci-update.toml"
{
  echo "# SoryOS incremental update: rebuild only these recipes from source"
  echo "[packages]"
  for name in $RECIPES; do
    echo "$name = \"source\""
  done
} > "$UPDATE_CONFIG"
printf 'update config (%s):\n' "$UPDATE_CONFIG" | tee -a "$LOG_FILE"
cat "$UPDATE_CONFIG" | tee -a "$LOG_FILE"

# ----------------------------------------------------------------------------
# 3. Stable ed25519 signing keys
# ----------------------------------------------------------------------------
mkdir -p build
if [[ -n "${SORYOS_PKGAR_SECRET_KEY:-}" && -n "${SORYOS_PKGAR_PUBLIC_KEY:-}" ]]; then
  printf '%s\n' "$SORYOS_PKGAR_SECRET_KEY" > build/id_ed25519.toml
  printf '%s\n' "$SORYOS_PKGAR_PUBLIC_KEY" > build/id_ed25519.pub.toml
  chmod 600 build/id_ed25519.toml
  printf 'installed stable ed25519 signing keys\n' | tee -a "$LOG_FILE"
else
  printf 'WARNING: no stable keys provided, keys will be generated locally\n' | tee -a "$LOG_FILE"
fi

# ----------------------------------------------------------------------------
# 4. Cook the changed recipes (repo_binary default, overridden to source)
# ----------------------------------------------------------------------------
printf 'cooking changed recipes (%s) with make repo...\n' "$RECIPES" | tee -a "$LOG_FILE"
set +e
make CONFIG_NAME=soryos \
  FILESYSTEM_CONFIG="$UPDATE_CONFIG" \
  PREFIX_BINARY=1 \
  REPO_BINARY=1 \
  REPO_BINARY_STRICT=1 \
  REPO_BINARY_REFRESH=1 \
  SORYOS_RELEASE_INDEX_URL="${SORYOS_RELEASE_INDEX_URL:-}" \
  SORYOS_RELEASE_REPOSITORY="${SORYOS_RELEASE_REPOSITORY:-sory-x/soryos-apt}" \
  SORYOS_RELEASE_STRICT=1 \
  PODMAN_BUILD=0 \
  SKIP_CHECK_TOOLS=1 \
  COOKBOOK_MAKE_JOBS="$MAKE_JOBS" \
  COOKBOOK_LOGS=true \
  repo >> "$LOG_FILE" 2>&1
MAKE_STATUS=$?
set -e
if [[ "$MAKE_STATUS" -ne 0 ]]; then
  printf 'make repo failed (exit %s), last log lines:\n' "$MAKE_STATUS" | tee -a "$LOG_FILE" >&2
  tail -80 "$LOG_FILE" | tee -a "$LOG_FILE" >&2
  LOGS_DIR="build/logs/$TARGET"
  if [[ -d "$LOGS_DIR" ]]; then
    find "$LOGS_DIR" -name '*.log' -newermt '-30 minutes' -print0 2>/dev/null | sort -z | while IFS= read -r -d '' f; do
      printf '=== %s (last 60 lines) ===\n' "$f" | tee -a "$LOG_FILE" >&2
      tail -60 "$f" | tee -a "$LOG_FILE" >&2
    done
  fi
  exit 2
fi

# ----------------------------------------------------------------------------
# 5. Prepare destination for the changed Release assets
# ----------------------------------------------------------------------------
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -a "repo/$TARGET" "$OUTPUT_DIR/$TARGET"

printf 'changed pkgar Release assets ready under: %s\n' "$OUTPUT_DIR" | tee -a "$LOG_FILE"
printf 'published packages: %s\n' "$(ls "$OUTPUT_DIR/$TARGET"/*.pkgar 2>/dev/null | wc -l)" | tee -a "$LOG_FILE"
