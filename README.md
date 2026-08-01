# SoryOS PKGAR Repository

Dépôt binaire SoryOS au format natif redox (`.pkgar`), publié sur GitHub Pages.

Ce dépôt reproduit la chaîne `make repo` du cookbook redox : chaque
application est cuite (`repo cook`), assemblée dans `repo/<target>/`
(`.pkgar` + `.toml` + `repo.toml`), signée ed25519, puis publiée à la racine
du dépôt, comme `https://static.redox-os.org/pkg`.

## Layout

```text
redox-apps/manifest.json               Liste des applications (source de vérité)
scripts/build-packages.sh              Build pkgar (cookbook redox -> repo/<target>/)
scripts/build-and-validate.sh          Build + validation de structure locale
scripts/ci-local.sh                    CI locale (syntaxe + build + validation)
.github/workflows/build-cosmic.yml     CI : build + publish pkgar sur GitHub Pages
.github/workflows/apt-repository.yml   CI : validation du build pkgar
logs/                                  Logs locaux
tmp/                                   Zone de travail (clone cookbook)
```

## Workflow CI

1. `detect-changes` : lit `redox-apps/manifest.json` (304 recettes).
2. `build` : `scripts/build-packages.sh` clone le cookbook
   (`SORYOS_REDOX_REPO`), compile `repo`/`repo_builder`, pose les clés
   ed25519 (secrets `SORYOS_PKGAR_SECRET_KEY`/`PUBLIC_KEY`), cuit
   `--filesystem=config/soryos.toml --repo-binary`, assemble `repo/`.
3. `publish` : remplace `repo/` et pousse sur `main` (servi par Pages).

## Configuration du build

| Variable | Défaut | Rôle |
|----------|--------|------|
| `SORYOS_REDOX_REPO` | `https://github.com/sory-x/Redox.git` | Cookbook à cloner |
| `SORYOS_REDOX_REF` | `master` | Réf du cookbook |
| `SORYOS_TARGET` | `x86_64-unknown-redox` | Cible → `repo/<target>/` |
| `SORYOS_FILESYSTEM_CONFIG` | `config/soryos.toml` | Liste des recettes à cuire |
| `SORYOS_PKGAR_OUTPUT` | `$ROOT_DIR/repo` | Racine publiée sur Pages |
| `SORYOS_PKGAR_WORK` | `$ROOT_DIR/tmp/build-$(id -u)` | Zone de travail |

## Consommation par redox

```text
repo.toml / *.pkgar / *.toml sous repo/<target>/  ->  redox_installer / pkgutils
id_ed25519.pub.toml à la racine                  ->  sync_keys
```

## Validation locale

```bash
./scripts/ci-local.sh
```
