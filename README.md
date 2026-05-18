# SoryOS APT Repository

Local APT repository for progressive SoryOS packages.

This repository is designed to be published with GitHub Pages later, but it is tested locally first.

## Rules

- Do not remove Pop!_OS repositories.
- Do not replace core packages in bulk.
- Add SoryOS packages module by module.
- Keep each change reversible.
- Test package indexes locally before publishing.

## Layout

```text
pool/*.deb                                Debian package files
dists/stable/main/binary-amd64/Packages   Plain APT package index
dists/stable/main/binary-amd64/Packages.gz Compressed APT package index
packages/                                 Package source templates
scripts/                                  Reproducible maintenance scripts
logs/                                     Local operation logs
```

## Current Starter Packages

- `sory-shell`
- `sory-theme`
- `sory-settings`
- `sory-installer`

These are minimal marker packages for repository validation. They do not replace Pop!_OS packages yet.

## Local Workflow

```bash
./scripts/build-packages.sh
./scripts/generate-index.sh
./scripts/test-local-repo.sh
./scripts/apt-smoke-test.sh
```

`apt-smoke-test.sh` uses an isolated temporary APT root under `tmp/` and does not modify `/etc/apt`.

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
