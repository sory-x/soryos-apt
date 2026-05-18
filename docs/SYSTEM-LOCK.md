# SoryOS System Lock

`soryos-system-lock` protects SoryOS packages during the Pop!_OS to SoryOS migration.

## What It Installs

- `/etc/apt/preferences.d/soryos.pref`
- `/usr/bin/soryos-apply-holds`
- `/usr/bin/soryos-remove-holds`

## APT Pinning

SoryOS packages are protected with priority `1000`:

```text
Package: sory* soryos-*
Pin: origin sory-x.github.io
Pin-Priority: 1000
```

SoryOS package names from other repositories are blocked:

```text
Package: sory* soryos-*
Pin: release *
Pin-Priority: -1
```

Pop!_OS and Ubuntu remain available as fallback sources:

```text
Package: *
Pin: origin archive.ubuntu.com
Pin-Priority: 50

Package: *
Pin: origin apt.pop-os.org
Pin-Priority: 50
```

## Install

```bash
sudo apt update
sudo apt install soryos-system-lock
```

It is also installed by:

```bash
sudo apt install soryos-desktop
```

## Optional Holds

Apply critical package holds:

```bash
sudo soryos-apply-holds
```

Remove those holds:

```bash
sudo soryos-remove-holds
```

The hold commands are manual on purpose. Installing `soryos-system-lock` does not silently hold packages.

## Verify

```bash
apt-cache policy soryos-system-lock soryos-desktop sory-shell sory-theme sory-settings sory-installer
apt-mark showhold
```

Expected SoryOS priority:

```text
1000
```

## Rollback

Remove holds:

```bash
sudo soryos-remove-holds
```

Remove the lock package:

```bash
sudo apt remove soryos-system-lock
sudo apt update
```

Remove SoryOS APT config entirely:

```bash
sudo ./scripts/rollback-soryos-apt.sh
```

Do not remove Pop!_OS base packages during early migration.
