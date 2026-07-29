#!/usr/bin/env bash
# Sauvegarde PostgreSQL avec verification d'integrite et rotation.
# Une sauvegarde jamais restauree n'est pas une sauvegarde : ce script
# controle systematiquement l'archive produite.
set -euo pipefail

CONTAINER="${PG_CONTAINER:-postgres}"
DB="${POSTGRES_DB:?POSTGRES_DB manquant}"
USER="${POSTGRES_USER:?POSTGRES_USER manquant}"
DEST="${BACKUP_DIR:-/var/backups/postgres}"
KEEP_DAYS="${KEEP_DAYS:-14}"
STAMP="$(date +%Y%m%d-%H%M%S)"
FILE="${DEST}/${DB}-${STAMP}.dump"

mkdir -p "$DEST"

echo "[1/4] Export de la base ${DB}"
docker exec -t "$CONTAINER" pg_dump -U "$USER" -Fc "$DB" > "$FILE"

echo "[2/4] Verification de l'archive"
if ! docker exec -i "$CONTAINER" pg_restore --list < "$FILE" > /dev/null 2>&1; then
  echo "ECHEC : archive illisible, elle est supprimee." >&2
  rm -f "$FILE"
  exit 1
fi

SIZE=$(du -h "$FILE" | cut -f1)
echo "[3/4] Archive valide : ${FILE} (${SIZE})"

echo "[4/4] Rotation, conservation ${KEEP_DAYS} jours"
find "$DEST" -name "${DB}-*.dump" -mtime "+${KEEP_DAYS}" -delete

# Copie hors site. Une sauvegarde sur le meme serveur ne protege de rien.
if [ -n "${S3_BUCKET:-}" ]; then
  aws s3 cp "$FILE" "s3://${S3_BUCKET}/postgres/" --storage-class STANDARD_IA
  echo "Copie envoyee vers s3://${S3_BUCKET}/postgres/"
fi
