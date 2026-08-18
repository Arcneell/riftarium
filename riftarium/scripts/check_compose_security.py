"""Refuse une config Compose qui republierait l'API ou des secrets d'exemple."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPOSE = ROOT / "compose.yaml"

PLACEHOLDERS = {
    "JWT_SECRET": "ci-jwt-secret-must-be-24-chars",
    "DB_PASSWORD": "ci-db-password-long-enough",
    "ADMIN_TOKEN": "ci-admin-token-16ch",
    "REDIS_PASSWORD": "ci-redis-password-ok",
}


def main() -> int:
    env = {**os.environ, **PLACEHOLDERS}
    raw = subprocess.check_output(
        ["docker", "compose", "-f", str(COMPOSE), "config", "--format", "json"],
        cwd=ROOT,
        env=env,
        text=True,
    )
    cfg = json.loads(raw)
    services = cfg["services"]

    api_ports = services["api"].get("ports") or []
    if api_ports:
        print("l'API ne doit pas publier de port hôte", file=sys.stderr)
        return 1

    api_env = services["api"].get("environment") or {}
    if api_env.get("RIFTARIUM_ENV") != "prod":
        print("RIFTARIUM_ENV=prod est requis pour le service api", file=sys.stderr)
        return 1
    if api_env.get("JWT_SECRET") in {"dev-secret-change-me", "test-secret"}:
        print("JWT_SECRET d'exemple encore interpolé", file=sys.stderr)
        return 1

    redis_cmd = services["redis"].get("command") or ""
    if isinstance(redis_cmd, list):
        redis_cmd = " ".join(redis_cmd)
    if "--requirepass" not in redis_cmd:
        print("Redis doit exiger un mot de passe", file=sys.stderr)
        return 1

    web_ports = services["web"].get("ports") or []
    if not web_ports:
        print("le front doit publier 8080 sur 127.0.0.1 (debug local, pas d'Internet)", file=sys.stderr)
        return 1
    saw_8080 = False
    for item in web_ports:
        if not isinstance(item, dict):
            print("format de port web inattendu", file=sys.stderr)
            return 1
        target = str(item.get("target") or "")
        host_ip = item.get("host_ip") or "0.0.0.0"
        if target == "8080":
            saw_8080 = True
            if host_ip in ("", "0.0.0.0", "::"):
                print("le front ne doit pas être publié sur 0.0.0.0 (contourne BunkerWeb)", file=sys.stderr)
                return 1
    if not saw_8080:
        print("le front doit écouter 8080 (nginx non-root)", file=sys.stderr)
        return 1

    print("compose security: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
