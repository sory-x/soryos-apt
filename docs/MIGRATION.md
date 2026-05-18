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

SoryOS packages matching `sory*` and `soryos-*` get priority `1000` from the SoryOS repository.

Other packages from SoryOS get priority `100` to prevent accidental broad replacement.

Ubuntu and Pop!_OS origins are pinned at priority `50`, so they remain available as fallback sources without overriding SoryOS packages.

SoryOS package names from non-SoryOS repositories are pinned at `-1` to prevent accidental replacement.

Detailed lock documentation: `docs/SYSTEM-LOCK.md`.

## Stage 1: Desktop Modules

```bash
sudo ./scripts/migrate-stage1-desktop.sh
```

Installs:

- `soryos-archive-keyring`
- `soryos-system-lock`
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
sudo apt remove soryos-desktop soryos-system-lock sory-installer sory-settings sory-theme sory-shell
```

Optional critical package holds:

```bash
sudo soryos-apply-holds
```

Rollback holds:

```bash
sudo soryos-remove-holds
```

Check status after rollback:

```bash
sudo apt update
apt-cache policy soryos-desktop soryos-system-lock sory-shell sory-theme sory-settings sory-installer
```

Do not remove Pop!_OS base packages during early migration.
