#!/usr/bin/env python3
"""Merge newly built packages into an existing signed SoryOS Release index.

Only the packages found in the build directory are replaced (or added) in the
index. Every other entry is left byte-for-byte untouched, so unchanged
packages are neither re-hashed nor re-published.

The release tag, the asset URLs and the signature URLs are preserved: the
updated index still points to the same immutable Release.

The script deliberately requires b3sum, matching generate-release-index.py,
so the digest is compatible with the package verification contract.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

IGNORED_ASSETS = {"repo.toml", "id_ed25519.pub.toml"}


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
        fail("b3sum is required; refusing to update a non-BLAKE3 index")
    except subprocess.CalledProcessError as exc:
        fail(f"cannot hash {path}: {exc}")
    return result.stdout.strip()


def make_asset(release_base: str, path: Path) -> dict:
    size = path.stat().st_size
    if size >= (1 << 30):
        fail(f"asset is not below the 1 GiB policy: {path} ({size} bytes)")
    return {
        "name": path.name,
        "url": f"{release_base}/{path.name}",
        "size": size,
        "blake3": blake3(path),
    }


def main() -> int:
    if len(sys.argv) != 5:
        print(
            f"usage: {sys.argv[0]} <existing-index> <new-packages-dir> "
            "<output-index> <release-tag>",
            file=sys.stderr,
        )
        return 2

    index_path = Path(sys.argv[1]).resolve()
    packages_dir = Path(sys.argv[2]).resolve()
    output = Path(sys.argv[3]).resolve()
    tag = sys.argv[4]

    if not index_path.is_file():
        fail(f"existing index does not exist: {index_path}")
    if not packages_dir.is_dir():
        fail(f"new packages dir does not exist: {packages_dir}")
    if not tag or "/" in tag or ".." in tag:
        fail("release tag must be a non-empty immutable tag name")

    try:
        document = json.loads(index_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"existing index is not valid JSON: {exc}")

    if document.get("schema") != 1:
        fail("existing index is not a schema 1 document")
    if not document.get("release", {}).get("immutable"):
        fail("existing index is not marked immutable")
    if document.get("repository") != "sory-x/soryos-apt":
        fail("existing index is not from sory-x/soryos-apt")

    release_base = (
        f"https://github.com/{document['repository']}/releases/download/{tag}"
    )

    # Discover the newly built packages (.pkgar + .toml metadata pairs).
    new_packages = {}
    for path in sorted(packages_dir.rglob("*")):
        if not path.is_file():
            continue
        name = path.name
        if name in IGNORED_ASSETS or name.endswith((".sig", ".hex", ".pem")):
            continue
        if name.endswith(".pkgar"):
            new_packages.setdefault(name.removesuffix(".pkgar"), {})["pkgar"] = path
        elif name.endswith(".toml"):
            new_packages.setdefault(name.removesuffix(".toml"), {})["metadata"] = path

    if not new_packages:
        fail("no new packages found in the build directory")

    assets = document.setdefault("assets", [])
    packages = document.setdefault("packages", {})
    changed = []

    for package_name in sorted(new_packages):
        files = new_packages[package_name]
        if set(files) != {"pkgar", "metadata"}:
            fail(
                f"package {package_name} is missing either .pkgar or metadata "
                f"(got: {', '.join(sorted(files))})"
            )
        pkgar_asset = make_asset(release_base, files["pkgar"])
        meta_asset = make_asset(release_base, files["metadata"])

        for asset in (pkgar_asset, meta_asset):
            replaced = False
            for existing in assets:
                if existing["name"] == asset["name"]:
                    existing.update(asset)
                    replaced = True
                    break
            if not replaced:
                assets.append(asset)

        entry = packages.setdefault(package_name, {})
        entry["pkgar"] = pkgar_asset
        entry["metadata"] = meta_asset
        changed.append(package_name)

    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".tmp")
    temporary.write_text(
        json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    os_replace(temporary, output)
    print(
        f"updated {output} with {len(assets)} assets; "
        f"changed packages: {', '.join(changed)}"
    )
    return 0


def os_replace(source: Path, destination: Path) -> None:
    import os

    os.replace(source, destination)


if __name__ == "__main__":
    raise SystemExit(main())
