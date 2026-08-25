"""Cache Redis optionnel.

Sans REDIS_URL (tests, dev sans Redis), toutes les fonctions sont des no-op :
l'API fonctionne à l'identique, simplement sans cache.
"""

import contextlib
import json
import logging
import time

from .config import settings

log = logging.getLogger("riftarium.cache")

# Sans REDIS_URL, Redis est désactivé pour de bon (pas de cible à joindre).
# Avec une URL mais un serveur injoignable, on retente après un délai : un simple
# blip au démarrage (ordre docker-compose) ne doit pas couper cache + rate-limiting
# pour toute la vie du process.
_RETRY_AFTER_SECONDS = 30

_client = None
_no_url = not settings.redis_url
_next_retry = 0.0


def _redis():
    global _client, _next_retry
    if _no_url:
        return None
    if _client is not None:
        return _client
    if time.monotonic() < _next_retry:  # en fenêtre de backoff après un échec récent
        return None
    try:
        import redis

        client = redis.Redis.from_url(settings.redis_url, socket_timeout=1, socket_connect_timeout=1)
        client.ping()
    except Exception:
        _next_retry = time.monotonic() + _RETRY_AFTER_SECONDS
        log.warning("Redis injoignable (%s) : nouvel essai dans %ds", settings.redis_url, _RETRY_AFTER_SECONDS)
        return None
    _client = client
    return _client


def cache_get(key: str):
    client = _redis()
    if client is None:
        return None
    try:
        raw = client.get(f"riftarium:{key}")
        return json.loads(raw) if raw else None
    except Exception:
        return None


def cache_set(key: str, value, ttl: int) -> None:
    client = _redis()
    if client is None:
        return
    with contextlib.suppress(Exception):
        client.setex(f"riftarium:{key}", ttl, json.dumps(value))


def cache_clear(prefix: str) -> int:
    client = _redis()
    if client is None:
        return 0
    try:
        keys = list(client.scan_iter(f"riftarium:{prefix}*"))
        if keys:
            client.delete(*keys)
        return len(keys)
    except Exception:
        return 0
