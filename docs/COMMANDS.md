# SoryOS APT Commands

This file is the single command reference for the SoryOS APT repository.

Run commands from the repository root unless stated otherwise:

```bash
cd /home/sory/Bureau/soryos/soryos-apt
```

## Full Local Build And Test

Use this before every push:

```bash
./scripts/init-signing-key.sh
./scripts/build-packages.sh
./scripts/sign-repository.sh
./scripts/test-local-repo.sh
./scripts/apt-smoke-test.sh
./scripts/apt-signed-smoke-test.sh
```

Test the published GitHub Pages repository:

```bash
./scripts/apt-pages-smoke-test.sh https://sory-x.github.io/soryos-apt
```

## Build Packages Only

```bash
./scripts/build-packages.sh
```

Generated packages are placed in:

```text
pool/*.deb
```

## Generate APT Index Only

```bash
./scripts/generate-index.sh
```

Equivalent raw command:

```bash
dpkg-scanpackages pool /dev/null | gzip -9cn > dists/stable/main/binary-amd64/Packages.gz
```

## Sign Repository Only

```bash
./scripts/sign-repository.sh
```

Generated signed metadata:

```text
dists/stable/Release
dists/stable/Release.gpg
dists/stable/InRelease
```

## Local Tests

Validate files and signatures:

```bash
./scripts/test-local-repo.sh
```

Test unsigned compatibility in an isolated APT root:

```bash
./scripts/apt-smoke-test.sh
```

Test signed APT in an isolated APT root:

```bash
./scripts/apt-signed-smoke-test.sh
```

These tests do not modify `/etc/apt`.

## Publish To GitHub

After local tests pass:

```bash
git status --short
git add .
git commit -m "Update SoryOS APT repository"
git push origin main
```

Then test GitHub Pages:

```bash
./scripts/apt-pages-smoke-test.sh https://sory-x.github.io/soryos-apt
```

## Configure SoryOS APT On A Test Machine

This adds SoryOS as a signed secondary repository. It does not remove Pop!_OS repositories.

```bash
sudo ./scripts/configure-soryos-apt.sh
```

It installs:

```text
/usr/share/keyrings/soryos-archive-keyring.gpg
/etc/apt/sources.list.d/soryos.list
/etc/apt/preferences.d/soryos.pref
```

Manual equivalent:

```bash
sudo install -d -m 0755 /usr/share/keyrings /etc/apt/sources.list.d /etc/apt/preferences.d
curl -fsSL https://sory-x.github.io/soryos-apt/keyrings/soryos-archive-keyring.gpg | sudo tee /usr/share/keyrings/soryos-archive-keyring.gpg >/dev/null
sudo chmod 0644 /usr/share/keyrings/soryos-archive-keyring.gpg
printf '%s\n' 'deb [signed-by=/usr/share/keyrings/soryos-archive-keyring.gpg] https://sory-x.github.io/soryos-apt stable main' | sudo tee /etc/apt/sources.list.d/soryos.list >/dev/null
sudo cp config/apt/preferences.d/soryos.pref /etc/apt/preferences.d/soryos.pref
sudo apt update
```

## Install Stage 1 Desktop Modules

```bash
sudo ./scripts/migrate-stage1-desktop.sh
```

Manual equivalent:

```bash
sudo apt update
apt-cache policy soryos-desktop sory-shell sory-theme sory-settings sory-installer
sudo apt install soryos-desktop
```

Expected behavior:

```text
0 removed
SoryOS packages installed module by module
Pop!_OS repositories kept enabled
```

## Install Base From Installed Package

After `sory-installer` is installed:

```bash
sudo soryos-install-base
```

## Rollback

Remove only SoryOS APT configuration:

```bash
sudo ./scripts/rollback-soryos-apt.sh
```

Manual equivalent:

```bash
sudo rm -f /etc/apt/sources.list.d/soryos.list
sudo rm -f /etc/apt/preferences.d/soryos.pref
sudo rm -f /usr/share/keyrings/soryos-archive-keyring.gpg
sudo apt update
```

Optionally remove SoryOS packages:

```bash
sudo apt remove soryos-desktop sory-installer sory-settings sory-theme sory-shell
```

Keep Pop!_OS base packages installed during early migration.

## Local Cleanup

Remove generated local packages and indexes:

```bash
./scripts/rollback-local.sh
```

This does not touch the system APT configuration.

## Important Safety Rules

- Do not remove Pop!_OS repositories during early migration.
- Do not use `[trusted=yes]` for final systems.
- Always run `apt update` before migration installs.
- Always test locally before pushing.
- Keep the private GPG key under `.private/gnupg` backed up and out of Git.
