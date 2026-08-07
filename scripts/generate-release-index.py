#!/usr/bin/env python3
"""Generate a deterministic SoryOS Release asset index.

The script deliberately requires b3sum.  Falling back to another digest would
make the index incompatible with the package verification contract.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

MAX_ASSET_SIZE = 1 << 30


def fail(message: str) -> "NoReturn":
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def blake3(path: Path) -> str:
    try:
        result = subprocess.run(
            ["b3sum", "--no-names", str(path)],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        fail("b3sum is required; refusing to generate a non-BLAKE3 index")
    except subprocess.CalledProcessError as exc:
        fail(f"cannot hash {path}: {exc}")
    return result.stdout.strip()


def main() -> int:
    if len(sys.argv) not in (5, 6, 7):
        print(
            f"usage: {sys.argv[0]} <asset-root> <release-tag> "
            "<release-repository> <output-index> [base-url] [public-key]",
            file=sys.stderr,
        )
        return 2

    root = Path(sys.argv[1]).resolve()
    tag = sys.argv[2]
    repository = sys.argv[3]
    output = Path(sys.argv[4]).resolve()
    base_url = sys.argv[5].rstrip("/") if len(sys.argv) >= 6 else ""
    if not root.is_dir():
        fail(f"asset root does not exist: {root}")
    if not tag or "/" in tag or ".." in tag:
        fail("release tag must be a non-empty immutable tag name")
    if not repository.count("/") == 1:
        fail("release repository must have the form owner/name")
    if not base_url:
        base_url = f"https://github.com/{repository}/releases/download/{tag}"

    assets = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path == output:
            continue
        size = path.stat().st_size
        if size >= MAX_ASSET_SIZE:
            fail(f"asset is not below the 1 GiB policy: {path} ({size} bytes)")
        relative = path.relative_to(root).as_posix()
        assets.append(
            {
                "name": relative,
                "url": f"{base_url}/{relative}",
                "size": size,
                "blake3": blake3(path),
            }
        )

    if not assets:
        fail("release contains no assets")
    if len(assets) > 1000:
        fail("release contains more than GitHub's 1000-asset limit")

    packages = {}
    for asset in assets:
        name = asset["name"]
        if name.endswith(".pkgar"):
            package_name = Path(name).name.removesuffix(".pkgar")
            packages.setdefault(package_name, {})["pkgar"] = asset
        elif name.endswith(".toml") and Path(name).name != "repo.toml":
            package_name = Path(name).name.removesuffix(".toml")
            packages.setdefault(package_name, {})["metadata"] = asset
    # Group recipes are dependency aliases. They intentionally publish only
    # metadata and are not installable archives, so they do not belong in the
    # Release asset index. A pkgar without metadata is invalid and remains a
    # hard error.
    metadata_only = sorted(
        name for name, files in packages.items()
        if set(files) == {"metadata"}
    )
    incomplete = sorted(
        name for name, files in packages.items()
        if set(files) not in ({"pkgar", "metadata"}, {"metadata"})
    )
    if incomplete:
        fail(
            "packages are missing either .pkgar or metadata: "
            + ", ".join(incomplete)
        )
    for name in metadata_only:
        packages.pop(name, None)
    if metadata_only:
        print(
            "skipping metadata-only group packages: "
            + ", ".join(metadata_only),
            file=sys.stderr,
        )

    # These URLs are deterministic and point to the immutable release that
    # will receive index.json and its detached signature below.
    release_base = base_url
    public_key = (
        Path(sys.argv[6]).resolve()
        if len(sys.argv) >= 7
        else root.parent / "id_ed25519.pub.toml"
    )
    public_key_asset = None
    if public_key.is_file():
        public_key_asset = {
            "name": public_key.name,
            "url": f"{release_base}/{public_key.name}",
            "size": public_key.stat().st_size,
            "blake3": blake3(public_key),
        }
    document = {
        "schema": 1,
        "repository": repository,
        "target": root.name,
        "release": {"tag": tag, "immutable": True},
        "assets": assets,
        "packages": packages,
        "pkgar_public_key": public_key_asset,
        "signature": {
            "url": f"{release_base}/index.json.sig",
            "public_key_url": f"{release_base}/index-signing-key.pub.pem",
            # The PEM key remains the host-side verification format. The raw
            # key is consumed by the native pkgutils ReleaseIndex backend.
            "runtime_public_key_url": f"{release_base}/index-signing-key.pub.hex",
        },
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".tmp")
    temporary.write_text(
        json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    os.replace(temporary, output)
    print(f"generated {output} with {len(assets)} assets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
