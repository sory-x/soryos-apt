# Publishing SoryOS APT To GitHub Pages

Do this only after local tests pass.

## 1. Create GitHub repository

Create an empty repository named:

```text
soryos-apt
```

## 2. Initialize local Git repository

```bash
cd /home/sory/Bureau/soryos/soryos-apt
git init
git branch -M main
git add .
git commit -m "Initialize SoryOS APT repository"
```

## 3. Push

Replace `<user>` with the real GitHub username or organization.

```bash
git remote add origin https://github.com/<user>/soryos-apt.git
git push -u origin main
```

## 4. Enable GitHub Pages

In repository settings:

```text
Pages -> Deploy from branch -> main -> /root
```

## 5. APT source line

For early unsigned testing only:

```text
deb [trusted=yes] https://<user>.github.io/soryos-apt stable main
```

Do not remove Pop!_OS repositories during testing.
