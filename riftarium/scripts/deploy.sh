#!/usr/bin/env bash
# Déploiement Compose sur le VPS. Appelé une fois le clone aligné sur origin/main.
# Le fichier .env local n'est pas versionné : il n'est ni lu depuis git ni écrasé.
# PREVIOUS_SHA (optionnel, exporté par deploy.yml avant le checkout) : SHA de la
# version précédente ; si le healthcheck échoue, on y revient (re-checkout + rebuild).
set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$COMPOSE_DIR"

if [[ ! -f .env ]]; then
  echo "manque $COMPOSE_DIR/.env — copier .env.example et renseigner les secrets." >&2
  exit 1
fi

if [[ ! -f compose.yaml ]]; then
  echo "compose.yaml introuvable dans $COMPOSE_DIR" >&2
  exit 1
fi

# Valeur éventuellement quotée (PORT="8888" ou PORT='8888') : on retire quotes et espaces.
PORT="$(awk -F= '/^PORT=/{gsub(/\r/,""); print $2; exit}' .env | tr -d "\"' ")"
PORT="${PORT:-8888}"

PREVIOUS_SHA="${PREVIOUS_SHA:-}"

build_and_up() {
  echo "construction des images…"
  docker compose build --pull
  echo "mise en service…"
  docker compose up -d --remove-orphans
}

# Attend que /api/health réponde {"status": "ok"} ; retourne 1 sinon (géré
# explicitement par l'appelant, pas via set -e).
wait_healthy() {
  local health_url="http://127.0.0.1:${PORT}/api/health"
  local body
  echo "attente de /api/health sur 127.0.0.1:${PORT}…"
  for _ in $(seq 1 60); do
    body=""
    if command -v curl >/dev/null 2>&1; then
      body="$(curl -fsS "$health_url" || true)"
    elif command -v wget >/dev/null 2>&1; then
      body="$(wget -q -O- "$health_url" || true)"
    else
      echo "installer curl ou wget" >&2
      exit 1
    fi
    if printf '%s' "$body" | grep -Eq '"status" *: *"ok"'; then
      return 0
    fi
    sleep 3
  done
  return 1
}

# Sauvegarde de la base AVANT toute mise à jour. Best-effort : au premier
# déploiement la base ne tourne pas encore, on ne bloque pas pour autant.
if ! bash scripts/backup_db.sh; then
  echo "avertissement : sauvegarde de la base impossible — on poursuit le déploiement." >&2
fi

build_and_up

if ! wait_healthy; then
  echo "l'API n'a pas répondu healthy à temps" >&2
  docker compose ps
  docker compose logs --tail=80 api web

  if [[ -n "$PREVIOUS_SHA" ]] && git rev-parse --verify --quiet "${PREVIOUS_SHA}^{commit}" >/dev/null; then
    current_sha="$(git rev-parse HEAD)"
    if [[ "$current_sha" != "$PREVIOUS_SHA" ]]; then
      echo "rollback : retour à ${PREVIOUS_SHA}…" >&2
      git checkout -B main "$PREVIOUS_SHA"
      build_and_up
      if wait_healthy; then
        echo "rollback ok : l'ancienne version (${PREVIOUS_SHA}) est de nouveau en service." >&2
      else
        echo "rollback effectué mais l'ancienne version ne répond pas non plus — intervention manuelle requise." >&2
      fi
    fi
  else
    echo "pas de SHA précédent connu : aucun rollback automatique possible." >&2
  fi

  echo "échec du déploiement : la nouvelle version n'a jamais répondu healthy." >&2
  exit 1
fi

docker image prune -f >/dev/null
docker compose ps
echo "déploiement ok"
