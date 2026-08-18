#!/usr/bin/env bash
# Déploiement Compose sur le VPS. Appelé une fois le clone aligné sur origin/main.
# Le fichier .env local n'est pas versionné : il n'est ni lu depuis git ni écrasé.
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

PORT="$(awk -F= '/^PORT=/{gsub(/\r/,""); print $2; exit}' .env)"
PORT="${PORT:-8888}"

echo "construction des images…"
docker compose build

echo "mise en service…"
docker compose up -d --remove-orphans

echo "attente de /api/health sur 127.0.0.1:${PORT}…"
health_url="http://127.0.0.1:${PORT}/api/health"
ok=0
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
  if printf '%s' "$body" | grep -q '"status"'; then
    ok=1
    break
  fi
  sleep 3
done

if [[ "$ok" -ne 1 ]]; then
  echo "l'API n'a pas répondu healthy à temps" >&2
  docker compose ps
  docker compose logs --tail=80 api web
  exit 1
fi

docker image prune -f >/dev/null
docker compose ps
echo "déploiement ok"
