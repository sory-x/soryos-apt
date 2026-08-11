#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# SoryOS - Build the Redox application set as native .pkgar binaries
# =============================================================================
# Reproduces `make repo` of the redox cookbook (same recipe as redox CI):
#   1. clone the cookbook (github.com/sory-x/Redox)
#   2. `make prefix` downloads the prebuilt toolchain (gcc/rust/clang/relibc)
#      from static.redox-os.org as .pkgar and extracts it
#   3. install the stable ed25519 signing keys (secrets) into build/
#   4. `make repo CONFIG_NAME=soryos REPO_BINARY=1` cooks the 304 recipes from
#      config/soryos.toml and assembles repo/<arch>/ (.pkgar + .toml + repo.toml)
#   5. copy repo/ to the temporary destination for GitHub Release publication
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/build-packages.log"
WORK_DIR="${SORYOS_PKGAR_WORK:-$ROOT_DIR/tmp/build-$(id -u)}"

REDOX_REPO="${SORYOS_REDOX_REPO:-https://github.com/sory-x/Redox.git}"
REDOX_REF="${SORYOS_REDOX_REF:-main}"
TARGET="${SORYOS_TARGET:-x86_64-unknown-redox}"
MANIFEST="$ROOT_DIR/redox-apps/manifest.json"
OUTPUT_DIR="${SORYOS_PKGAR_OUTPUT:-$ROOT_DIR/repo}"
FILESYSTEM_CONFIG="${SORYOS_FILESYSTEM_CONFIG:-config/soryos.toml}"
MAKE_JOBS="${SORYOS_MAKE_JOBS:-$(nproc 2>/dev/null || echo 2)}"
RECIPES_SELECTION="${SORYOS_RECIPES:-all}"
REPO_BINARY="${SORYOS_REPO_BINARY:-1}"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

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

# The cookbook may carry an older config/soryos.toml. Always replace it with
# the SoryOS apt configuration so the Release contains every intended app,
# including packages added after the cookbook fork.
printf 'installing SoryOS filesystem config from apt repository...\n' | tee -a "$LOG_FILE"
mkdir -p "$(dirname "$FILESYSTEM_CONFIG")"
cp "$ROOT_DIR/$FILESYSTEM_CONFIG" "$FILESYSTEM_CONFIG"
if [[ ! -f "$FILESYSTEM_CONFIG" ]]; then
  printf 'missing filesystem config: %s (copy it from sory-os-apt)\n' \
    "$FILESYSTEM_CONFIG" | tee -a "$LOG_FILE" >&2
  exit 1
fi

if [[ "$RECIPES_SELECTION" != "all" ]]; then
  SELECTION_CONFIG="$WORK_DIR/redox/config/soryos-ci-selected.toml"
  python3 - "$FILESYSTEM_CONFIG" "$SELECTION_CONFIG" "$RECIPES_SELECTION" <<'PY'
import json
import tomllib
from pathlib import Path

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
names = sys.argv[3].split()

# Keep the per-package rules (e.g. "source" for recipes not yet published
# in the signed Release) that exist in the source config, so a
# selection/validation build still rebuilds those from source under strict
# binary mode instead of failing on "absent from the signed Release index".
# PackageConfig is #[serde(untagged)]: a bare string deserializes to
# Build(rule), while a `{ rule = "..." }` map silently becomes Spec{} and
# falls back to the default (binary) rule under REPO_BINARY=1.
rules = {}
with open(source, "rb") as fh:
    for name, cfg in tomllib.load(fh).get("packages", {}).items():
        if isinstance(cfg, dict) and cfg.get("rule"):
            rules[name] = cfg["rule"]
        elif isinstance(cfg, str):
            rules[name] = cfg

text = source.read_text(encoding="utf-8")
prefix = text.split("[packages]", 1)[0]
entries = []
for name in names:
    rule = rules.get(name)
    entries.append(f"{name} = {rule!r}\n" if rule else f"{name} = {{}}\n")
destination.write_text(
    prefix + "[packages]\n" + "".join(entries),
    encoding="utf-8",
)
print(f"selected recipes: {', '.join(names)} (rules kept for {len(rules)})")
PY
  FILESYSTEM_CONFIG="$SELECTION_CONFIG"
fi

# ----------------------------------------------------------------------------
# 2. Stable ed25519 signing keys (like SORYOS_GPG_KEY for apt)
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
# 3. Build the repository (prefix toolchain + cook + repo_builder)
# ----------------------------------------------------------------------------
# `make repo` handles everything in dependency order:
#   - prefix  : downloads prebuilt gcc/rust/clang/relibc .pkgar (PREFIX_BINARY=1)
#   - fstools : compiles installer/redoxfs for the host
#   - cook    : cooks the recipes of config/soryos.toml (--repo-binary)
#   - publish : repo_builder assembles repo/<target>/ (.pkgar + .toml + repo.toml)
printf 'building pkgar repo with make repo (config=%s, jobs=%s)...\n' \
  "$FILESYSTEM_CONFIG" "$MAKE_JOBS" | tee -a "$LOG_FILE"
set +e
make CONFIG_NAME=soryos \
  FILESYSTEM_CONFIG="$FILESYSTEM_CONFIG" \
  PREFIX_BINARY=1 \
  REPO_BINARY="$REPO_BINARY" \
  REPO_BINARY_STRICT=1 \
  REPO_BINARY_REFRESH=1 \
  SORYOS_RELEASE_INDEX_URL="${SORYOS_RELEASE_INDEX_URL:-}" \
  SORYOS_RELEASE_REPOSITORY="${SORYOS_RELEASE_REPOSITORY:-sory-x/soryos-apt}" \
  SORYOS_RELEASE_STRICT=1 \
  PODMAN_BUILD=0 \
  SKIP_CHECK_TOOLS=1 \
  COOKBOOK_MAKE_JOBS="$MAKE_JOBS" \
  COOKBOOK_LOGS=true \
  repo 2>&1 | tee -a "$LOG_FILE"
MAKE_STATUS=${PIPESTATUS[0]}
set -e
if [[ "$MAKE_STATUS" -ne 0 ]]; then
  printf 'make repo failed (exit %s), last log lines:\n' "$MAKE_STATUS" | tee -a "$LOG_FILE" >&2
  tail -80 "$LOG_FILE" | tee -a "$LOG_FILE" >&2
  printf 'most recent recipe logs:\n' | tee -a "$LOG_FILE" >&2
  LOGS_DIR="build/logs/$TARGET"
  if [[ -d "$LOGS_DIR" ]]; then
    find "$LOGS_DIR" -name '*.log' -newermt '-30 minutes' -print0 2>/dev/null | sort -z | while IFS= read -r -d '' f; do
      printf '=== %s (last 80 lines) ===\n' "$f" | tee -a "$LOG_FILE" >&2
      tail -80 "$f" | tee -a "$LOG_FILE" >&2
    done
  fi
  exit 2
fi

# ----------------------------------------------------------------------------
# 4. Prepare destination for GitHub Release assets
# ----------------------------------------------------------------------------
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -a "repo/$TARGET" "$OUTPUT_DIR/$TARGET"

# The public key must be served at the repo root for `sync_keys`
if [[ -f build/id_ed25519.pub.toml ]]; then
  cp -a "build/id_ed25519.pub.toml" "$OUTPUT_DIR/id_ed25519.pub.toml"
fi

printf 'pkgar Release assets ready under: %s\n' "$OUTPUT_DIR" | tee -a "$LOG_FILE"
printf 'published packages: %s\n' "$(ls "$OUTPUT_DIR/$TARGET"/*.pkgar 2>/dev/null | wc -l)" | tee -a "$LOG_FILE"
