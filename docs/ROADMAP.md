# SoryOS Distribution Roadmap

## Phase 1: Secure APT

Status: started.

- Generate `Packages.gz` from `pool/`.
- Generate `Release` with `apt-ftparchive`.
- Generate `Release.gpg` and `InRelease` with GPG.
- Publish public keyring files.
- Provide `soryos-archive-keyring` package.
- Test local and GitHub Pages APT access using `signed-by`.

## Phase 2: Installer

Status: started.

- `scripts/install-soryos-repo.sh` configures the signed repo on a test system.
- `sory-installer` provides `soryos-install-base`.
- Current base install only installs `sory-shell`, `sory-theme`, and `sory-settings`.

## Phase 3: ISO Integration

Status: planned.

- Add SoryOS keyring to the ISO chroot.
- Add SoryOS APT source with `signed-by`.
- Install SoryOS packages during ISO build.
- Keep Pop!_OS repositories enabled during early migration.

## Phase 4: Progressive Replacement

Status: planned.

Order:

1. Shell module.
2. Theme module.
3. Settings module.
4. System tools.
5. Installer replacement.

Do not replace all Pop!_OS packages at once.

## Phase 5: CI/CD

Status: started.

- CI validates package build.
- CI validates repository signing.
- CI validates isolated APT access.
- Future: publish from CI using protected signing secrets.
