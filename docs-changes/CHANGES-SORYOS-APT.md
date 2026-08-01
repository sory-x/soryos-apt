# Changements effectués pour SoryOS — `sory-os-apt/`

Ce fichier documente toutes les modifications apportées au dossier
`sory-os-apt/` pour l'adapter au projet SoryOS.

> **Règle :** chaque changement fait dans `sory-os-apt/` doit être documenté
> ici, fichier par fichier, partie par partie, avec son **Avant/Après** et toute
> **erreur potentielle** liée au changement pour référence rapide.

---

## Historique des changements

### 2026-08-01 — Correction pipeline de publication APT

Corrections pour que le CI construise les binaires d'applications et les
publie de façon cohérente sur le dépôt APT (GitHub Pages).

| Fichier | Section | Changement | Erreurs potentielles |
|---------|---------|------------|----------------------|
| `.github/workflows/build-cosmic.yml` | job `publish` / "Sign repository" | Import de la clé GPG désormais fait dans `$PWD/.private/gnupg` (avec `GNUPGHOME` exporté + `mkdir`/`chmod 700`) au lieu de `~/.gnupg` par défaut | `sign-repository.sh` force `GNUPGHOME=$ROOT_DIR/.private/gnupg`. Avant, la clé importée dans `~/.gnupg` était introuvable → `gpg: missing signing GNUPGHOME` ou échec `--local-user`, donc index jamais re-signé. Si le secret `SORYOS_GPG_KEY` est absent/incorrect : échec d'import ou signature refusée par apt (`NO_PUBKEY`). |
| `.github/workflows/build-cosmic.yml` | job `detect-changes` | Normalisation de `pool_ver` avec `${pool_ver%%+soryos*}` pour comparer à `src_ver` (Rust et Make) | Avant, `src_ver` (`1.0.2`) ≠ `pool_ver` (`1.0.2+soryos1`) → rebuild de TOUT à chaque run quotidien. Après, comparaison juste. Si un paquet n'a pas de suffixe `+soryos`: la coupe ne change rien (pattern présent mais absent = inchangé). |
| `.github/workflows/build-cosmic.yml` | job `detect-changes` | Nouvelle sortie `index_resync` + détection des `Filename:` manquants dans `dists/stable/main/binary-amd64/Packages` par rapport à `pool/` | Si le fichier référencé existe mais que son contenu diffère : pas de resync (le cas réel est un fichier absent). Un `pool/` corrompu (extension `.deb` manquante) → resync inutile. |
| `.github/workflows/build-cosmic.yml` | job `build` | Inchangé (ne tourne que si `has_changes=true`) | — |
| `.github/workflows/build-cosmic.yml` | job `publish` | Condition élargie : `has_changes == 'true' || index_resync == 'true'` ; step "Download all .deb artifacts" conditionné sur `has_changes` ; suppression du step redondant "Generate Packages index" | Sans condition, un resync seul aurait été ignoré → désynchro persistante. Le step de téléchargement skip évite l'échec quand aucun build n'a tourné (`no artifacts`). Le `Release` écrit à la main (sans checksums MD5/SHA) et le `binary-all/` orphelin disparaissent : `sign-repository.sh` (via `generate-index.sh` + `apt-ftparchive`) les régénère correctement. |
| `.github/workflows/build-cosmic.yml` | job `publish` / "Commit and push" | Message de commit : utilise `CHANGES` si présent, sinon message dédié `Index resync: regenerate Packages from pool` | Si `changes` vide et `resync=false` : aucun commit (inchangé). |
| `scripts/build-packages.sh` | boucle de build | `rm -f "$POOL_DIR"/*.deb` remplacé par suppression ciblée `"$POOL_DIR/${name}"_*.deb` par paquet reconstruit | Avant, un run de ce script (déclenché par `apt-repository.yml` sur chaque push) supprimait TOUS les `.deb` du pool, y compris les COSMIC publiés par `build-cosmic.yml` → paquets COSMIC volatils. Après, seuls les `.deb` soryos-* reconstruits sont retirés. Risque résiduel : si un paquet COSMIC partage le même nom que la liste, il serait supprimé (aucun cas aujourd'hui). |

---

### 2026-08-01 — Migration binaire `.deb` → `.pkgar` (format natif redox)

Le dépôt `sory-os-apt` publie désormais des binaires **`.pkgar`** (format
d'application natif de redox) au lieu des `.deb`. La chaîne de build CI
reproduit le `make repo` du cookbook redox : chaque application est cuite
(`repo cook --all`), assemblée par `repo_builder` dans `repo/<target>/`
(`.pkgar` + `.toml` + `repo.toml`), signée ed25519, puis publiée sur GitHub
Pages à la racine du dépôt (comme `static.redox-os.org/pkg`).

**Principe retenu :** pas de fichiers dupliqués. Les rôles existants sont
réutilisés et modifiés (build, build+publish, validation) — aucun nouveau
script de build séparé n'a été conservé.

| Fichier | Section | Changement | Erreurs potentielles |
|---------|---------|------------|----------------------|
| `scripts/build-packages.sh` | tout | Le script de build existant est désormais le build **pkgar** : clone du cookbook redox (`SORYOS_REDOX_REPO`/`REF`), compile `repo` + `repo_builder`, pose les clés ed25519 (`SORYOS_PKGAR_SECRET_KEY`/`PUBLIC_KEY`), `cook --all` (ou `SORYOS_RECIPES`), assemble `repo/$SORYOS_TARGET/`, copie vers `$SORYOS_PKGAR_OUTPUT` + `id_ed25519.pub.toml` à la racine | Sans secrets, les clés sont générées localement (instables entre runs) → signatures invalides au run suivant. La compilation redox exige un runner adapté. |
| `.github/workflows/build-cosmic.yml` | tout | Renommé de rôle : c'est le workflow **build+publish pkgar**. Jobs `detect-changes` (lit le manifeste → toujours `has_changes=true`, comme `make repo`), `build` (rust-toolchain stable → `./scripts/build-packages.sh` → artifact `pkgar-repo`), `publish` (remplace `repo/` et push). Déclencheurs : `workflow_dispatch` (recipes, force_rebuild) + schedule 02:00 UTC | Le suffixe `+soryos` / index APT ne s'appliquent plus ; les secrets `SORYOS_GPG_KEY` ne servent plus ici. |
| `.github/workflows/apt-repository.yml` | tout | Workflow de **validation** : build pkgar (rust-toolchain) puis vérifie `repo-out/$TARGET/repo.toml`, `id_ed25519.pub.toml` et la présence d'au moins un `*.pkgar` | Validation de structure, pas de vérification de signature. |
| `scripts/build-and-validate.sh` | tout | Validation locale alignée : build pkgar vers `tmp/repo-validate-*` puis même contrôle de structure | — |
| `scripts/build-pkgar-repo.sh` | — | **Supprimé** (doublon de `build-packages.sh`) | — |
| `.github/workflows/build-pkgar.yml` | — | **Supprimé** (doublon de `build-cosmic.yml`) | — |
| `redox-apps/manifest.json` | — | Nouveau : liste des 305 recettes hors `wip/` du cookbook redox (source pour `detect-changes` et référence de recettes) | Doit rester synchronisé avec `redox/recipes/`. |

Notes de configuration du build pkgar (variables `SORYOS_*` passées au script) :

| Variable | Défaut | Rôle |
|----------|--------|------|
| `SORYOS_REDOX_REPO` | `https://gitlab.com/sory-os/redox.git` | Cookbook à cloner |
| `SORYOS_REDOX_REF` | `master` | Réf (branche/tag) du cookbook |
| `SORYOS_TARGET` | `x86_64-unknown-redox` | Cible → sous-dossier `repo/<target>/` |
| `SORYOS_RECIPES` | vide = toutes | Sous-ensemble de recettes à cuire |
| `SORYOS_PKGAR_OUTPUT` | `$ROOT_DIR/repo` | Destination (racine Pages) |
| `SORYOS_PKGAR_WORK` | `$ROOT_DIR/tmp/build-$(id -u)` | Zone de travail (clone cookbook) |
| `SORYOS_FILESYSTEM_CONFIG` | `config/soryos.toml` | Config filesystem du cookbook (liste des recettes à cuire) |

---

### 2026-08-01 — Sources git du cookbook : alignement des dépôts redox

Audit des URLs des sources de toutes les recettes hors `wip/` (305 au départ) :

| Hôte | Recettes | Statut |
|------|----------|--------|
| `github.com` | 103 | Upstream, tel quel (pas de fork SoryOS) |
| `gitlab.com/sory-os` | 78 | Forks SoryOS |
| tarballs upstream (`ftp.gnu.org`, `download.gnome.org`, …) | ~70 | `tar = url` + `blake3`, tel quel |
| `gitlab.redox-os.org` (ancien gitlab redox) | 2 | Traitées ci-dessous |

| Fichier | Section | Changement | Erreurs potentielles |
|---------|---------|------------|----------------------|
| `redox/recipes/tests/schedrs/recipe.toml` | `[source]` | `git = "https://gitlab.redox-os.org/akshitgaur2005/schedrs.git"` → `https://gitlab.com/sory-os/schedrs.git` | Recette identique dans le cookbook redox officiel ; dépôt source encore accessible, mais fork SoryOS créé pour la souveraineté (token API, projet `sory-os/schedrs`, `git push --mirror` depuis le bare clone). |
| `redox/recipes/other/jeremy/recipe.toml` | — | **Inchangé** mais recette **exclue du build** | `jeremy` est un dépôt **privé** (`# This is a private repository`) : impossible à cloner en CI sans auth → échec systématique. Le cookbook redox officiel la contient aussi (commentaire identique). |
| `redox-apps/manifest.json` | — | `schedrs` : `git` → `gitlab.com/sory-os/schedrs.git`, `origin` → `fork-sory-os`. `jeremy` : **retiré du manifeste** | Le manifeste passe de 305 à **304** recettes. |
| `redox/config/soryos.toml` | — | **Nouveau** : config filesystem du cookbook listant les 304 recettes (`include = ["base.toml"]` + `[packages]`), générée depuis `manifest.json` | — |
| `scripts/build-packages.sh` | step 4 | `repo cook --all` remplacé par `repo cook --filesystem=config/soryos.toml --repo-binary` | `cook --all` (`staged_pkg::list()`) parcourt TOUT `recipes/` y compris les ~3000 stubs `wip/` et les dépôts privés → build interminable + échec `jeremy`. Le `--filesystem` (mécanisme officiel `make repo` : `COOKBOOK_OPTS=--filesystem=$(FILESYSTEM_CONFIG) --repo-binary`) sélectionne exactement la liste. |
| `scripts/build-packages.sh` | step 5 | Fallback `repo_builder` : liste des paquets désormais lue depuis `config/soryos.toml` au lieu de `find recipes` | `cook --filesystem` lance déjà `repo_builder` en fin de chaîne (`main.rs:285`) ; ce fallback ne sert qu'en secours. |

Référence mécanique `repo` (sources) :

| Point | Référence |
|-------|-----------|
| `cook` télécharge les sources avant de cuire | `src/bin/repo/main.rs:381` (`handle_fetch` → `handle_cook`) |
| Clone git des sources | `src/cook/fetch.rs:221` (`git clone`, avec `translate_mirror`) |
| Tarballs vérifiés par blake3 | `src/cook/fetch.rs:111-125` |
| `cook --all` parcourt tout `recipes/` (incl. wip) | `src/staged_pkg.rs:15-37` + `main.rs:552-556` |
| `cook --filesystem` lit `conf.packages` | `main.rs:590-598`, config lue via `redox_installer::Config` |
| `cook` publie via `repo_builder` | `main.rs:285`, `main.rs:444-462` (spawn `repo_builder` avec la liste) |
| `repo_builder` assemble `repo/<target>/` | `src/bin/repo_builder.rs:46-77` (`redoxer::target()`, exclut les paquets `is_host`) |

---

### 2026-08-01 — Suppression complète de l'ancien pipeline APT

Le dépôt devient 100 % pkgar. Tout l'ancien contenu `.deb`/APT est supprimé
(car il ne servira plus : les binaires redox sont des `.pkgar`).

| Fichier / dossier | Sort | Raison |
|-------------------|------|--------|
| `pool/` | Supprimé | 56 `.deb` (243 MB) de l'ancien dépôt APT (SoryOS + COSMIC) |
| `dists/` | Supprimé | Index APT (`Packages`, `Release`, signatures) obsolète |
| `keyrings/` | Supprimé | Clé GPG `soryos-archive-keyring` inutilisée (signature = ed25519 pkgar) |
| `config/apt/` | Supprimé | Pinning / sources APT (ISO Ubuntu seulement) |
| `packages/` | Supprimé | Templates des paquets `.deb` d'intégration |
| `tests/` (apt, chroot, qemu) | Supprimé | Tests du pipeline APT |
| `scripts/generate-index.sh`, `sign-repository.sh`, `init-signing-key.sh`, `test-local-repo.sh`, `apt-*-smoke-test.sh`, `validate-apt-safety.sh`, `test-apt-guard-scenarios.sh`, `configure-soryos-apt.sh`, `install-soryos-repo.sh`, `rollback-*.sh`, `migrate-stage1-desktop.sh`, `test-chroot-*.sh` | Supprimés | Scripts du pipeline APT, orphelins depuis la migration pkgar |
| `scripts/lib/` (chroot-common.sh) | Supprimé | Dépendances des tests chroot APT |
| `scripts/publish-github-pages.md` | Supprimé | Documentation APT Pages obsolète |
| `docs/` | Supprimé | Documentation APT (COMMANDS, ISO-INTEGRATION, MIGRATION, RELEASES, ROADMAP, SECURITY, SYSTEM-LOCK) — remplacée par `docs-changes/` + `README.md` |
| `scripts/ci-local.sh` | Réécrit | Ne fait plus que : syntaxe bash → `build-and-validate.sh` (pkgar). Supprimées les références aux smoke tests APT et aux tests chroot. |
| `README.md` | Réécrit | Décrit le dépôt pkgar (layout, workflow CI, variables `SORYOS_*`, consommation redox) |
| `.gitignore` | Adapté | Garde `logs/`, `tmp/`, `.private/`, ajoute `repo-out/` (sortie de validation locale). `repo/` et `*.pkgar` sont volontairement **committés** (livrable publié sur Pages). |

Après suppression, le dépôt ne contient plus que : `README.md`, `.gitignore`,
`.github/workflows/{build-cosmic,apt-repository}.yml`, `scripts/{build-packages,
build-and-validate,ci-local}.sh`, `redox-apps/manifest.json`,
`docs-changes/CHANGES-SORYOS-APT.md` (140K au total).

L'historique git distant (contenant 141 `.deb` historiques) est **réinitialisé**
sur un commit racine unique pour purger les binaires et accélérer le clone.

---

## Répertoire des erreurs connues

> Section à remplir à chaque changement. Toute erreur observée en lien avec un
> changement doit être référencée ici.

| Erreur | Fichier | Ligne | Cause | Correctif |
|--------|---------|-------|-------|-----------|
| Désynchronisation index↔pool : `cosmic-comp_1.0.0_amd64.deb`, `cosmic-icons_1.0.0_all.deb`, `cosmic-idle_1.0.0_amd64.deb`, `cosmic-notifications_1.0.0_amd64.deb` référencés mais absents du pool (le pool contient les versions `+soryos1`) | `dists/stable/main/binary-amd64/Packages` | — | Index généré avant l'ajout des versions `+soryos1` et jamais re-signé (échec GPG dû au GNUPGHOME erroné) | Fix `GNUPGHOME` + nouvelle détection `index_resync` : le prochain run CI régénère `Packages` depuis `pool/` et re-signe |
| 2 fichiers orphelins dans le pool, non référencés | `pool/cosmic-wallpapers_1.0.0_amd64.deb`, `pool/cosmic-workspaces-epoch_1.0.0_amd64.deb` | — | Anciennes versions restantes après mise à niveau `+soryos1` | Regénération de l'index (les inclura) ou suppression manuelle si obsolètes |
| Clé GPG locale ≠ fingerprint committé | `keyrings/FINGERPRINT` (`5E33510C…`) vs `~/.gnupg` (`413296B6…`) | — | La clé de signature du dépôt n'est pas sur la machine de dev | La signature se fait uniquement dans le CI (secret `SORYOS_GPG_KEY`) |
| `sign-repository.sh` régénère index + Release + signatures pour `stable testing nightly` | `scripts/sign-repository.sh:32-56` | — | Les 3 suites partagent le même pool ; le CI ne publie que `stable` | Vérifier si `testing`/`nightly` doivent être maintenus |
| `jeremy` est un dépôt privé : échec au `git clone` en CI (`could not read Username`) | `redox/recipes/other/jeremy/recipe.toml` | — | Dépôt `gitlab.redox-os.org/jackpot51/jeremy.git` non public | Retiré du manifeste `redox-apps/manifest.json` (pas dans `config/soryos.toml`) |
| `cook --all` cuisinerait les ~3000 recettes `wip/` + les dépôts privés | `scripts/build-packages.sh` (ancien) | — | `staged_pkg::list()` parcourt tout `recipes/` | Utiliser `cook --filesystem=config/soryos.toml --repo-binary` (mécanisme officiel) |

---

## Notes de référence

- **Workflow CI principal** : `.github/workflows/build-cosmic.yml` (build pkgar → `repo/<target>/` → GitHub Pages).
- **Workflow validation** : `.github/workflows/apt-repository.yml`.
- **Chaîne build** : `scripts/build-packages.sh` (cookbook redox → `.pkgar`) → copie `repo/` + `id_ed25519.pub.toml`.
- **Dépôt publié** : `https://sory-x.github.io/soryos-apt` (GitHub Pages).
- **Clé ed25519 pkgar** : secrets `SORYOS_PKGAR_SECRET_KEY` / `SORYOS_PKGAR_PUBLIC_KEY` (fichiers `build/id_ed25519.toml`, `build/id_ed25519.pub.toml` dans le cookbook).
