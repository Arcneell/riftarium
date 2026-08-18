"""Cache Redis optionnel.

Sans REDIS_URL (tests, dev sans Redis), toutes les fonctions sont des no-op :
l'API fonctionne à l'identique, simplement sans cache.
"""

import contextlib
import json
import logging

from .config import settings

log = logging.getLogger("riftarium.cache")

_client = None
_disabled = not settings.redis_url


def _redis():
    global _client, _disabled
    if _disabled:
        return None
    if _client is None:
        try:
            import redis

            _client = redis.Redis.from_url(
                settings.redis_url, socket_timeout=1, socket_connect_timeout=1
            )
            _client.ping()
        except Exception:
            log.warning("Redis injoignable (%s) : cache désactivé", settings.redis_url)
            _client = None
            _disabled = True
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
