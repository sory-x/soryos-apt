#!/bin/bash

set -e

# Assure que jq et les outils Nix sont dans le PATH
export PATH="/nix/store/jj9hkc8i90yb3dpcyyqlncijyj71w9id-replit-runtime-path/bin:$PATH"

echo "================================="
echo " SoryOS - Redox Auto Import"
echo "================================="

##################################
# Vérification dépendances
##################################

echo "[1/7] Vérification dépendances..."

for cmd in curl jq; do
    if ! command -v "$cmd" >/dev/null; then
        echo "ERREUR : '$cmd' introuvable dans le PATH"
        exit 1
    fi
done

echo "curl et jq OK"

##################################
# Configuration
##################################

TOKEN="$GITLAB_TOKEN"

SOURCE="https://gitlab.redox-os.org"
DEST="https://gitlab.com"

SOURCE_GROUP="redox-os"
DEST_GROUP="sory-os"

if [ -z "$TOKEN" ]; then
    echo "ERREUR : GITLAB_TOKEN absent. Ajoute-le dans Replit Secrets."
    exit 1
fi

##################################
# Groupe Redox
##################################

echo "[2/7] Recherche groupe Redox..."

REDOX_ID=$(curl -s "$SOURCE/api/v4/groups?search=$SOURCE_GROUP" | jq -r '.[0].id')

if [ "$REDOX_ID" = "null" ] || [ -z "$REDOX_ID" ]; then
    echo "Groupe Redox introuvable"
    exit 1
fi

echo "Redox ID : $REDOX_ID"

##################################
# Groupe SoryOS
##################################

echo "[3/7] Recherche groupe SoryOS..."

SORY_RESP=$(curl --header "PRIVATE-TOKEN: $TOKEN" -s "$DEST/api/v4/groups/$DEST_GROUP")
SORY_ID=$(echo "$SORY_RESP" | jq -r '.id')

if [ "$SORY_ID" = "null" ] || [ -z "$SORY_ID" ]; then
    echo "Groupe SoryOS introuvable"
    echo "Réponse API : $SORY_RESP"
    exit 1
fi

echo "SoryOS ID : $SORY_ID"

##################################
# Import automatique
##################################

echo "[4/7] Import projets..."

PAGE=1
TOTAL=0

while true; do
    echo ""
    echo "====== PAGE $PAGE ======"

    PROJECTS=$(curl -s "$SOURCE/api/v4/groups/$REDOX_ID/projects?per_page=100&page=$PAGE")
    COUNT=$(echo "$PROJECTS" | jq 'length')

    if [ "$COUNT" -eq 0 ]; then
        echo "Plus de projets, fin."
        break
    fi

    echo "Projets sur cette page : $COUNT"

    while IFS= read -r PROJECT; do
        NAME=$(echo "$PROJECT"  | jq -r '.name')
        PPATH=$(echo "$PROJECT" | jq -r '.path')
        URL=$(echo "$PROJECT"   | jq -r '.http_url_to_repo')

        echo ""
        echo "→ $NAME  ($URL)"

        EXIST=$(curl --header "PRIVATE-TOKEN: $TOKEN" -s \
            "$DEST/api/v4/projects/$DEST_GROUP%2F$PPATH" | jq -r '.id')

        if [ "$EXIST" != "null" ] && [ -n "$EXIST" ]; then
            echo "  Déjà présent, on passe."
            TOTAL=$((TOTAL + 1))
            continue
        fi

        RESULT=$(curl --silent --request POST \
            --header "PRIVATE-TOKEN: $TOKEN" \
            --data "name=$NAME" \
            --data "path=$PPATH" \
            --data "namespace_id=$SORY_ID" \
            --data-urlencode "import_url=$URL" \
            "$DEST/api/v4/projects")

        IMPORT_ID=$(echo "$RESULT" | jq -r '.id')
        if [ "$IMPORT_ID" != "null" ] && [ -n "$IMPORT_ID" ]; then
            echo "  ✓ Importé : $NAME"
            TOTAL=$((TOTAL + 1))
        else
            ERR=$(echo "$RESULT" | jq -r '.message // .error // "inconnue"')
            echo "  ✗ Erreur $NAME : $ERR"
        fi

    done < <(echo "$PROJECTS" | jq -c '.[]')

    PAGE=$((PAGE + 1))
done

##################################
# Résumé
##################################

echo ""
echo "================================="
echo " IMPORT TERMINÉ"
echo "================================="
echo "Projets traités : $TOTAL"
echo "Destination : https://gitlab.com/$DEST_GROUP"
