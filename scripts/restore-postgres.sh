#!/usr/bin/env bash
# Restauration. A tester en environnement de recette au moins une fois par trimestre.
set -euo pipefail
FILE="${1:?Usage: restore-postgres.sh <fichier.dump>}"
CONTAINER="${PG_CONTAINER:-postgres}"
DB="${POSTGRES_DB:?}"; USER="${POSTGRES_USER:?}"

read -rp "Restaurer ${FILE} dans ${DB} ? Les donnees actuelles seront ecrasees. [oui/NON] " ok
[ "$ok" = "oui" ] || { echo "Annule."; exit 1; }

docker exec -i "$CONTAINER" pg_restore -U "$USER" -d "$DB" --clean --if-exists < "$FILE"
echo "Restauration terminee."
