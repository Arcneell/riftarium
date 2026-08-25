#!/usr/bin/env bash
# Sauvegarde PostgreSQL : pg_dump dans le conteneur db, compressé en gzip.
# Appelé par deploy.sh avant chaque mise en service, et utilisable en cron :
#   0 4 * * * cd /opt/riftarium/riftarium && bash scripts/backup_db.sh >> /var/log/riftarium-backup.log 2>&1
# Copie hors-site automatique si BACKUP_REMOTE est défini (rclone) — voir plus bas.
set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$COMPOSE_DIR"

# Nombre de sauvegardes conservées (les plus anciennes sont supprimées).
RETENTION="${BACKUP_RETENTION:-14}"
BACKUP_DIR="${BACKUP_DIR:-$COMPOSE_DIR/backups}"
# Destination hors-site (rclone) : indispensable, la copie locale meurt avec le VPS.
# Exemple dans .env :  BACKUP_REMOTE=ovh-s3:riftarium-backups
# Vide = pas de copie distante (un avertissement est émis).
BACKUP_REMOTE="${BACKUP_REMOTE:-}"

# Comme deploy.sh : Compose interpole les secrets depuis .env (non versionné).
if [[ ! -f .env ]]; then
  echo "manque $COMPOSE_DIR/.env — sauvegarde impossible." >&2
  exit 1
fi

# Premier déploiement ou base arrêtée : rien à sauvegarder, on n'échoue pas.
if ! docker compose ps --services --status running db 2>/dev/null | grep -qx "db"; then
  echo "service db non démarré — sauvegarde ignorée."
  exit 0
fi

mkdir -p "$BACKUP_DIR"
stamp="$(date +%Y%m%d-%H%M%S)"
out="$BACKUP_DIR/riftarium-${stamp}.sql.gz"

echo "sauvegarde de la base vers $out…"
# POSTGRES_USER / POSTGRES_DB sont déjà définis dans le conteneur db.
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' | gzip > "$out"

if [[ ! -s "$out" ]]; then
  echo "sauvegarde vide : $out" >&2
  rm -f -- "$out"
  exit 1
fi

# Intégrité : un dump tronqué peut être non vide mais corrompu. gzip -t relit tout
# le flux compressé et échoue si l'archive est incomplète.
if ! gzip -t "$out"; then
  echo "sauvegarde corrompue (gzip -t a échoué) : $out" >&2
  rm -f -- "$out"
  exit 1
fi

# Copie hors-site : une sauvegarde qui ne quitte pas le VPS ne protège de rien.
if [[ -n "$BACKUP_REMOTE" ]]; then
  echo "copie hors-site vers $BACKUP_REMOTE…"
  if ! rclone copy "$out" "$BACKUP_REMOTE"; then
    echo "échec de la copie hors-site vers $BACKUP_REMOTE" >&2
    exit 1
  fi
else
  echo "BACKUP_REMOTE non défini : sauvegarde locale uniquement (aucune copie hors-site)." >&2
fi

# Rétention : on garde les $RETENTION fichiers les plus récents.
ls -1t "$BACKUP_DIR"/riftarium-*.sql.gz 2>/dev/null | tail -n +$((RETENTION + 1)) | while IFS= read -r old; do
  echo "rotation : suppression de $old"
  rm -f -- "$old"
done

echo "sauvegarde ok : $out"
