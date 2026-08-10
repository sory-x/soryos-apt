# SoryOS — Redox Auto Import

Script d'import automatique de tous les projets du groupe **Redox OS** (`gitlab.redox-os.org`) vers le groupe **SoryOS** sur GitLab.com.

## Prérequis

- `curl` et `jq` (installés automatiquement si absents)
- Un **Personal Access Token** GitLab.com avec les scopes : `api`, `read_api`
- Le groupe `sory-os` doit exister sur `gitlab.com`

## Configuration

Ajoute ton token GitLab dans les **Replit Secrets** :

| Clé | Valeur |
|-----|--------|
| `GITLAB_TOKEN` | Ton token GitLab.com |

## Utilisation

```bash
chmod +x sory-os-import/redox-auto-import.sh
bash sory-os-import/redox-auto-import.sh
```

## Ce que fait le script

1. Vérifie les dépendances (`curl`, `jq`)
2. Vérifie que `GITLAB_TOKEN` est présent
3. Récupère l'ID du groupe `redox-os` sur `gitlab.redox-os.org`
4. Récupère l'ID du groupe `sory-os` sur `gitlab.com`
5. Parcourt tous les projets Redox (100 par page)
6. Pour chaque projet : vérifie s'il existe déjà, sinon l'importe
7. Affiche un résumé à la fin

## Résultat

Tous les projets sont disponibles sur :
👉 `https://gitlab.com/sory-os`
