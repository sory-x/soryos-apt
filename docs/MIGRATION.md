# SoryOS Progressive Migration

The migration keeps Pop!_OS repositories enabled and adds SoryOS as a signed secondary APT source.

Full command reference: `docs/COMMANDS.md`.

## Stage 0: Configure APT

```bash
sudo ./scripts/configure-soryos-apt.sh
```

This installs:

- `/usr/share/keyrings/soryos-archive-keyring.gpg`
- `/etc/apt/sources.list.d/soryos.list`
- `/etc/apt/preferences.d/soryos.pref`

It then runs `apt-get update`.

No Pop!_OS repository is removed.

## APT Priority

SoryOS packages matching `sory*` and `soryos-*` get priority `700` from the SoryOS repository.

Other packages from SoryOS get priority `100` to prevent accidental broad replacement.

## Stage 1: Desktop Modules

```bash
sudo ./scripts/migrate-stage1-desktop.sh
```

Installs:

- `soryos-archive-keyring`
- `sory-shell`
- `sory-theme`
- `sory-settings`
- `sory-installer`
- `soryos-desktop`

The script does not remove Pop!_OS packages.

## Rollback

Remove the SoryOS APT source and keyring:

```bash
sudo ./scripts/rollback-soryos-apt.sh
```

Optional package rollback:

```bash
sudo apt remove soryos-desktop sory-installer sory-settings sory-theme sory-shell
```

Check status after rollback:

```bash
sudo apt update
apt-cache policy soryos-desktop sory-shell sory-theme sory-settings sory-installer
```

Do not remove Pop!_OS base packages during early migration.
