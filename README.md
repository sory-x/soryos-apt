# SoryOS APT Repository

Local APT repository for progressive SoryOS packages.

This repository is designed to be published with GitHub Pages later, but it is tested locally first.

## Rules

- Do not remove Pop!_OS repositories.
- Do not replace core packages in bulk.
- Add SoryOS packages module by module.
- Keep each change reversible.
- Test package indexes locally before publishing.
- Sign the repository with `Release`, `Release.gpg`, and `InRelease` before publishing.

## Layout

```text
pool/*.deb                                Debian package files
dists/stable/main/binary-amd64/Packages   Plain APT package index
dists/stable/main/binary-amd64/Packages.gz Compressed APT package index
dists/stable/Release                      Signed repository metadata source
dists/stable/Release.gpg                  Detached GPG signature
dists/stable/InRelease                    Inline GPG signature
keyrings/                                 Public SoryOS archive keyring
packages/                                 Package source templates
scripts/                                  Reproducible maintenance scripts
logs/                                     Local operation logs
```

## Current Starter Packages

- `sory-shell`
- `sory-theme`
- `sory-settings`
- `sory-installer`
- `soryos-archive-keyring`
- `soryos-desktop`

These are minimal progressive migration packages. They do not replace Pop!_OS packages yet.

`sory-installer` provides:

```bash
sudo soryos-install-base
```

The command installs only the current SoryOS base modules and does not remove Pop!_OS packages.

`soryos-desktop` is the first metapackage for the staged desktop migration.

## Local Workflow

```bash
./scripts/init-signing-key.sh
./scripts/build-packages.sh
./scripts/sign-repository.sh
./scripts/test-local-repo.sh
./scripts/apt-smoke-test.sh
./scripts/apt-signed-smoke-test.sh
./scripts/apt-pages-smoke-test.sh https://sory-x.github.io/soryos-apt
```

`apt-smoke-test.sh` uses an isolated temporary APT root under `tmp/` and does not modify `/etc/apt`.
`apt-pages-smoke-test.sh` performs the same style of isolated signed test against the published GitHub Pages URL.

CI validates package build, index generation, repository signing, and isolated APT access on every push and pull request.

## Signed APT Usage

Install the SoryOS keyring and source entry with:

```bash
sudo ./scripts/install-soryos-repo.sh
```

For migration, prefer the staged scripts:

```bash
sudo ./scripts/configure-soryos-apt.sh
sudo ./scripts/migrate-stage1-desktop.sh
```

Manual source entry:

```text
deb [signed-by=/usr/share/keyrings/soryos-archive-keyring.gpg] https://sory-x.github.io/soryos-apt stable main
```

`[trusted=yes]` is only for temporary testing and should not be used for final systems.

## GitHub Pages Workflow

After local validation and after setting the GitHub user/repository:

```bash
git remote add origin https://github.com/<user>/soryos-apt.git
git push -u origin main
```

Enable GitHub Pages from the repository settings, serving from the `main` branch root.

APT URL format:

```text
https://<user>.github.io/soryos-apt
```

Example source entry, after publication:

```text
deb [trusted=yes] https://<user>.github.io/soryos-apt stable main
```

The `[trusted=yes]` form is only for early testing. A signed repository should replace it before real users depend on it.
