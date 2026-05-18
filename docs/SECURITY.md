# SoryOS APT Security

The repository is signed with an APT archive key.

Published files:

- `dists/stable/Release`
- `dists/stable/Release.gpg`
- `dists/stable/InRelease`
- `keyrings/soryos-archive-keyring.asc`
- `keyrings/soryos-archive-keyring.gpg`
- `keyrings/FINGERPRINT`

The private key is generated under `.private/gnupg` by default and is ignored by Git.

## Client Configuration

Preferred source entry:

```text
deb [signed-by=/usr/share/keyrings/soryos-archive-keyring.gpg] https://sory-x.github.io/soryos-apt stable main
```

Do not use `[trusted=yes]` except for temporary early testing.

## Rollback

```bash
sudo rm -f /etc/apt/sources.list.d/soryos.list
sudo rm -f /usr/share/keyrings/soryos-archive-keyring.gpg
sudo apt update
```
