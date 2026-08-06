# SoryOS PKGAR Repository

Dépôt binaire SoryOS au format natif Redox (`.pkgar`), publié dans des GitHub
Releases immuables. GitHub Pages ne sert que les index signés et les clés
publiques.

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
scripts/generate-release-index.py      Génère l’index BLAKE3 des assets Release
scripts/sign-release-index.sh          Signe l’index avec une clé Ed25519 CI
scripts/verify-release-index.sh        Vérifie l’index et sa signature
.github/workflows/build-cosmic.yml     CI : build + publish pkgar dans Release
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
3. `publish` : crée une Release immuable et téléverse les `.pkgar`, `.toml`,
   `repo.toml`, les clés publiques et l’index signé.

## Configuration du build

| Variable | Défaut | Rôle |
|----------|--------|------|
| `SORYOS_REDOX_REPO` | `https://github.com/sory-x/Redox.git` | Cookbook à cloner |
| `SORYOS_REDOX_REF` | `main` | Réf du cookbook |
| `SORYOS_TARGET` | `x86_64-unknown-redox` | Cible → `repo/<target>/` |
| `SORYOS_FILESYSTEM_CONFIG` | `config/soryos.toml` | Liste des recettes à cuire |
| `SORYOS_PKGAR_OUTPUT` | `$ROOT_DIR/repo` | Racine temporaire des assets Release |
| `SORYOS_PKGAR_WORK` | `$ROOT_DIR/tmp/build-$(id -u)` | Zone de travail |
| `SORYOS_PKGAR_SECRET_KEY` / `PUBLIC_KEY` | — | Paire ed25519 de signature (secrets GitHub, sauvegarde dans `.private/`) |
| `SORYOS_INDEX_PRIVATE_KEY_PEM` | — | Clé Ed25519 dédiée à la signature de `index.json` des Releases |

## Consommation par Redox

```text
GitHub Release / index.json signé -> cookbook Redox avec `SORYOS_RELEASE_INDEX_URL`
*.pkgar + *.toml vérifiés          -> redox_installer / cookbook
id_ed25519.pub.toml                -> vérification de signature PKGAR
```

Le backend Redox consomme maintenant l’index signé d’une Release et vérifie la
taille et le BLAKE3 de chaque asset avant utilisation. Avec
`SORYOS_RELEASE_STRICT=1`, aucun fallback Pages n’est accepté.

La clé `SORYOS_INDEX_PRIVATE_KEY_PEM` est distincte de la clé PKGAR. Elle ne
doit jamais être commitée ni publiée. Seule sa clé publique
`index-signing-key.pub.pem` peut être distribuée avec l’index.

## Validation locale

```bash
./scripts/ci-local.sh
```
