# SoryOS ISO Integration

Goal: make the SoryOS ISO consume the SoryOS APT repository without removing Pop!_OS repositories during early migration.

Full command reference: `docs/COMMANDS.md`.

## Current Repository

```text
deb [signed-by=/usr/share/keyrings/soryos-archive-keyring.gpg] https://sory-x.github.io/soryos-apt stable main
```

## Required ISO Steps

Inside the ISO chroot, before installing SoryOS packages:

1. Install the public keyring:

```bash
install -Dm0644 soryos-archive-keyring.gpg /usr/share/keyrings/soryos-archive-keyring.gpg
```

2. Add the SoryOS APT source:

```bash
cat >/etc/apt/sources.list.d/soryos.list <<'EOF'
deb [signed-by=/usr/share/keyrings/soryos-archive-keyring.gpg] https://sory-x.github.io/soryos-apt stable main
EOF
```

3. Update APT and install only the current SoryOS base modules:

```bash
apt-get update
apt-get install -y soryos-archive-keyring soryos-system-lock sory-shell sory-theme sory-settings sory-installer soryos-desktop
```

4. Optional ISO lock mode after installation:

```bash
soryos-apply-holds
```

Keep this optional until the ISO is tested, because automatic holds can interfere with emergency base system updates.

## Rules

- Do not remove Pop!_OS sources during early migration.
- Do not replace `pop-desktop`, `pop-installer`, or `system76-*` packages until SoryOS replacement packages exist.
- Integrate one SoryOS module at a time.
- Keep rollback simple: remove `/etc/apt/sources.list.d/soryos.list`, remove SoryOS packages, then `apt update`.

## Future ISO Builder Patch Area

Likely Pop!_OS ISO builder files to inspect before editing:

- `iso/config/pop-os/24.04.mk`
- `iso/mk/chroot.mk`
- `iso/scripts/repos.sh`
- `iso/data/apt-preferences`

The ISO lock mode should install `soryos-system-lock` and keep Pop!_OS repositories enabled with lower priority during early migration.

Do not patch these until the signed APT repo is published and verified.
