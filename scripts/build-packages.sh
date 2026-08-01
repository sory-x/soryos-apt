#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# SoryOS - Build the Redox application set as native .pkgar binaries
# =============================================================================
# Reproduces the `make repo` build of the redox cookbook:
#   1. clone the cookbook (gitlab.com/sory-os/redox)
#   2. compile the `repo` tool
#   3. install the stable ed25519 signing keys (secrets) into build/
#   4. cook every recipe from the manifest -> .pkgar in recipes/*/target/<arch>/
#   5. repo_builder assembles repo/<arch>/ (.pkgar + .toml + repo.toml)
#   6. copy repo/ to the destination for GitHub Pages publication
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/build-packages.log"
WORK_DIR="${SORYOS_PKGAR_WORK:-$ROOT_DIR/tmp/build-$(id -u)}"

REDOX_REPO="${SORYOS_REDOX_REPO:-https://gitlab.com/sory-os/redox.git}"
REDOX_REF="${SORYOS_REDOX_REF:-master}"
TARGET="${SORYOS_TARGET:-x86_64-unknown-redox}"
MANIFEST="$ROOT_DIR/redox-apps/manifest.json"
OUTPUT_DIR="${SORYOS_PKGAR_OUTPUT:-$ROOT_DIR/repo}"

# Recipes to build. Default: every recipe in the manifest.
RECIPES="${SORYOS_RECIPES:-}"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing required tool: %s\n' "$1" | tee -a "$LOG_FILE" >&2
    exit 1
  fi
}

require_tool git
require_tool cargo
require_tool rustc

if [[ ! -f "$MANIFEST" ]]; then
  printf 'missing manifest: %s\n' "$MANIFEST" | tee -a "$LOG_FILE" >&2
  exit 1
fi

# ----------------------------------------------------------------------------
# 1. Clone the cookbook
# ----------------------------------------------------------------------------
if [[ -d "$WORK_DIR/redox/.git" ]]; then
  git -C "$WORK_DIR/redox" fetch origin >> "$LOG_FILE" 2>&1
  git -C "$WORK_DIR/redox" checkout "$REDOX_REF" >> "$LOG_FILE" 2>&1
else
  mkdir -p "$WORK_DIR"
  git clone --depth 1 --branch "$REDOX_REF" "$REDOX_REPO" "$WORK_DIR/redox" >> "$LOG_FILE" 2>&1
fi

cd "$WORK_DIR/redox"

# ----------------------------------------------------------------------------
# 2. Compile the `repo` tool (cookbook CLI)
# ----------------------------------------------------------------------------
printf 'compiling repo tool...\n' | tee -a "$LOG_FILE"
cargo build --release --bin repo --bin repo_builder >> "$LOG_FILE" 2>&1

# ----------------------------------------------------------------------------
# 3. Stable ed25519 signing keys (like SORYOS_GPG_KEY for apt)
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
# 4. Build recipes
# ----------------------------------------------------------------------------
# The cookbook uses config/*.toml filesystem configs to select the recipe set
# (`cook --all` would also build the 3000+ wip stubs and private repos).
# config/soryos.toml lists the 304 applications from the manifest.
FILESYSTEM_CONFIG="${SORYOS_FILESYSTEM_CONFIG:-config/soryos.toml}"
if [[ ! -f "$FILESYSTEM_CONFIG" ]]; then
  printf 'missing filesystem config: %s\n' "$FILESYSTEM_CONFIG" | tee -a "$LOG_FILE" >&2
  exit 1
fi

if [[ -z "$RECIPES" ]]; then
  printf 'building recipes from %s ...\n' "$FILESYSTEM_CONFIG" | tee -a "$LOG_FILE"
  ./target/release/repo cook --filesystem="$FILESYSTEM_CONFIG" --repo-binary >> "$LOG_FILE" 2>&1
else
  printf 'building recipes: %s\n' "$RECIPES" | tee -a "$LOG_FILE"
  ./target/release/repo cook $RECIPES --with-package-deps >> "$LOG_FILE" 2>&1
fi

# ----------------------------------------------------------------------------
# 5. Assemble repo/<target>/ (.pkgar + .toml + repo.toml) via repo_builder
#    `cook` already spawns repo_builder at the end; this is a safety net that
#    re-runs it with the filesystem config package list if repo.toml is absent.
# ----------------------------------------------------------------------------
printf 'assembling repo/%s ...\n' "$TARGET" | tee -a "$LOG_FILE"
if [[ ! -f repo/$TARGET/repo.toml ]]; then
  RECIPE_LIST=$(grep -E '^[a-zA-Z0-9._-]+ = ' "$FILESYSTEM_CONFIG" | awk '{print $1}' | tr '\n' ' ')
  ./target/release/repo_builder "repo" $RECIPE_LIST >> "$LOG_FILE" 2>&1
fi

# ----------------------------------------------------------------------------
# 6. Publish to destination (GitHub Pages root)
# ----------------------------------------------------------------------------
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -a "repo/$TARGET" "$OUTPUT_DIR/$TARGET"

# The public key must be served at the repo root for `sync_keys`
cp -a "build/id_ed25519.pub.toml" "$OUTPUT_DIR/id_ed25519.pub.toml"

printf 'pkgar repository ready under: %s\n' "$OUTPUT_DIR" | tee -a "$LOG_FILE"
printf 'published packages: %s\n' "$(ls "$OUTPUT_DIR/$TARGET"/*.pkgar 2>/dev/null | wc -l)" | tee -a "$LOG_FILE"
