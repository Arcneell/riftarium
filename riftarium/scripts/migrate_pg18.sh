#!/usr/bin/env bash
# Migration PostgreSQL 16 -> 18. À lancer sur le VPS, dans riftarium/, AVANT de
# merger le passage de compose.yaml en postgres:18-alpine.
#
# Pourquoi un script dédié
# ------------------------
# Les images postgres 18+ ont déplacé PGDATA vers /var/lib/postgresql/<majeur>/docker
# (docker-library/postgres#1259). Le volume dbdata est monté sur
# /var/lib/postgresql/data : ce n'est donc plus le répertoire de données.
#   - Sur l'ANCIEN volume, l'image 18 détecte le cluster 16 et REFUSE de démarrer.
#     Elle ne l'écrase pas : pas de perte de données, le déploiement échoue et
#     deploy.sh revient à la version précédente.
#   - Sur un volume NEUF, elle initialise une base VIDE, alembic recrée les tables
#     vides, pg_isready répond : le déploiement est déclaré réussi avec un site
#     vide, et aucun rollback ne se déclenche. C'est le cas dangereux.
# D'où l'ordre imposé : on remplit le nouveau volume AVANT de merger.
#
# pg_upgrade demanderait les binaires 16 ET 18 dans la même image ; pour une base
# de cette taille un dump/restore est plus simple et vérifiable.
#
# Ce script ne touche JAMAIS le volume dbdata (cluster 16) : le retour arrière
# reste possible en remettant compose.yaml en postgres:16-alpine avec
# dbdata:/var/lib/postgresql/data.
#
# La base reste EN SERVICE pendant tout le script : pg_dump est cohérent sur une
# base vivante, il n'y a pas d'interruption ici. En revanche les écritures faites
# ENTRE ce script et le déploiement sur 18 seraient perdues : enchaîner les deux.
set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$COMPOSE_DIR"

PROJECT="${COMPOSE_PROJECT_NAME:-$(basename "$COMPOSE_DIR")}"
NEW_VOLUME="${PROJECT}_dbdata18"
TMP_CONTAINER="riftarium-pg18-migration"
TARGET_IMAGE="postgres:18-alpine"
DUMP_DIR="${BACKUP_DIR:-$COMPOSE_DIR/backups}"
PGUSER_NAME="riftarium"
PGDB_NAME="riftarium"

# count(*) réel, et non n_live_tup : cette colonne est une estimation du
# collecteur de statistiques, elle peut être fausse (observée au double pendant
# la mise au point) et ne vaut donc rien comme contrôle d'intégrité.
COUNT_QUERY="select relname, (xpath('/row/cnt/text()', xml_count))[1]::text::bigint
  from (select relname,
               query_to_xml(format('select count(*) as cnt from %I.%I', schemaname, relname),
                            false, true, '') as xml_count
        from pg_stat_user_tables) t
  order by relname"

log() { printf '\n== %s\n' "$1"; }
fail() { printf 'ERREUR : %s\n' "$1" >&2; exit 1; }
cleanup() { docker rm -f "$TMP_CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

[[ -f .env ]] || fail "manque $COMPOSE_DIR/.env"
[[ -f compose.yaml ]] || fail "compose.yaml introuvable dans $COMPOSE_DIR"

DB_PASSWORD="$(awk -F= '/^DB_PASSWORD=/{sub(/^DB_PASSWORD=/,""); gsub(/\r/,""); print; exit}' .env | tr -d "\"' ")"
[[ -n "$DB_PASSWORD" ]] || fail "DB_PASSWORD absent de .env"

log "1/7 contrôles préalables"
docker compose ps --services --status running db 2>/dev/null | grep -qx db \
  || fail "le service db ne tourne pas : rien à migrer"

current="$(docker compose exec -T db psql -U "$PGUSER_NAME" -d "$PGDB_NAME" -tAc 'show server_version' | tr -d '\r')"
current_major="${current%%.*}"
echo "   serveur actuel : $current"
[[ "$current_major" -lt 18 ]] || fail "le serveur est déjà en $current_major : rien à faire"

if docker volume inspect "$NEW_VOLUME" >/dev/null 2>&1; then
  if [[ -n "$(docker run --rm -v "$NEW_VOLUME":/v "$TARGET_IMAGE" sh -c 'ls -A /v 2>/dev/null')" ]]; then
    fail "le volume $NEW_VOLUME existe et n'est pas vide. Si c'est un essai précédent : docker volume rm $NEW_VOLUME"
  fi
else
  docker volume create "$NEW_VOLUME" >/dev/null
fi
echo "   volume cible : $NEW_VOLUME"

log "2/7 empreinte de la base 16 (comptages réels par table)"
counts_before="$(mktemp)"
docker compose exec -T db psql -U "$PGUSER_NAME" -d "$PGDB_NAME" -tAF' ' -c "$COUNT_QUERY" \
  | tr -d '\r' | sed '/^$/d' > "$counts_before"
[[ -s "$counts_before" ]] || fail "aucune table trouvée dans la base source"
sed 's/^/   /' "$counts_before"

log "3/7 sauvegarde"
mkdir -p "$DUMP_DIR"
stamp="$(date +%Y%m%d-%H%M%S)"
dump="$DUMP_DIR/pre-pg18-${stamp}.sql.gz"
docker compose exec -T db sh -c "pg_dump -U '$PGUSER_NAME' '$PGDB_NAME'" | gzip > "$dump"
[[ -s "$dump" ]] || fail "sauvegarde vide : $dump"
echo "   $dump ($(du -h "$dump" | cut -f1))"

log "4/7 postgres 18 temporaire sur le nouveau volume"
docker rm -f "$TMP_CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$TMP_CONTAINER" \
  -v "$NEW_VOLUME":/var/lib/postgresql \
  -e POSTGRES_DB="$PGDB_NAME" \
  -e POSTGRES_USER="$PGUSER_NAME" \
  -e POSTGRES_PASSWORD="$DB_PASSWORD" \
  "$TARGET_IMAGE" >/dev/null
for _ in $(seq 1 60); do
  docker exec "$TMP_CONTAINER" pg_isready -U "$PGUSER_NAME" -d "$PGDB_NAME" >/dev/null 2>&1 && break
  sleep 2
done
docker exec "$TMP_CONTAINER" pg_isready -U "$PGUSER_NAME" -d "$PGDB_NAME" >/dev/null 2>&1 \
  || fail "le postgres 18 temporaire n'est pas prêt : docker logs $TMP_CONTAINER"
target="$(docker exec "$TMP_CONTAINER" psql -U "$PGUSER_NAME" -d "$PGDB_NAME" -tAc 'show server_version' | tr -d '\r')"
tgt_dir="$(docker exec "$TMP_CONTAINER" psql -U "$PGUSER_NAME" -d "$PGDB_NAME" -tAc 'show data_directory' | tr -d '\r')"
echo "   serveur cible : $target (data_directory : $tgt_dir)"

log "5/7 restauration du dump dans 18"
gunzip -c "$dump" | docker exec -i "$TMP_CONTAINER" \
  psql -U "$PGUSER_NAME" -d "$PGDB_NAME" -v ON_ERROR_STOP=1 -q \
  || fail "restauration échouée — supprimer $NEW_VOLUME avant un nouvel essai"

log "6/7 vérification : comptages 16 contre 18"
counts_after="$(mktemp)"
docker exec "$TMP_CONTAINER" psql -U "$PGUSER_NAME" -d "$PGDB_NAME" -tAF' ' -c "$COUNT_QUERY" \
  | tr -d '\r' | sed '/^$/d' > "$counts_after"
if diff -u "$counts_before" "$counts_after" > /tmp/pg18-counts.diff; then
  echo "   identiques sur $(wc -l < "$counts_after" | tr -d ' ') tables"
else
  echo "   ÉCART détecté :"
  sed 's/^/   /' /tmp/pg18-counts.diff
  fail "les comptages diffèrent — ne pas merger, inspecter d'abord"
fi

log "7/7 arrêt du conteneur temporaire (le volume reste rempli)"
docker rm -f "$TMP_CONTAINER" >/dev/null
trap - EXIT

cat <<EOS

Migration des données terminée.

  volume rempli   : $NEW_VOLUME (postgres $target)
  volume conservé : ${PROJECT}_dbdata (postgres $current, intact — retour arrière)
  sauvegarde      : $dump

Étape suivante, à enchaîner sans attendre (les écritures faites d'ici là seraient
perdues) : merger le passage de compose.yaml en postgres:18-alpine avec le montage
dbdata18:/var/lib/postgresql. Le déploiement recréera db sur le volume déjà rempli.

Retour arrière : remettre compose.yaml en postgres:16-alpine avec
dbdata:/var/lib/postgresql/data et redéployer. Les données 16 n'ont pas bougé.
EOS
