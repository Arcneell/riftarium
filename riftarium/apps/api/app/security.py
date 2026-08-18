"""Garde-fous transverses : IP client, rate limit, images, jeton admin."""

from __future__ import annotations

import hashlib
import hmac
import threading
import time
from collections import defaultdict, deque
from contextlib import suppress
from urllib.parse import urlparse

from fastapi import HTTPException, Request

from .config import settings

SESSION_COOKIE = "riftarium_session"

DEFAULT_IMAGE_HOSTS = frozenset({"cmsassets.rgpub.io", "assetcdn.rgpub.io"})
DEV_IMAGE_HOSTS = frozenset({"cdn.example"})

_hits: dict[str, deque[float]] = defaultdict(deque)
_lock = threading.Lock()


def client_ip(request: Request) -> str:
    """IP client après nginx real_ip (X-Real-IP posé par BunkerWeb)."""
    real = (request.headers.get("x-real-ip") or "").strip()
    if real:
        return real.split(",")[0].strip() or "0"
    if request.client and request.client.host:
        return request.client.host
    return "0"


def tokens_match(provided: str | None, expected: str | None) -> bool:
    if not provided or not expected:
        return False
    left = hashlib.sha256(provided.encode()).digest()
    right = hashlib.sha256(expected.encode()).digest()
    return hmac.compare_digest(left, right)


def require_admin_token(provided: str | None) -> None:
    if not tokens_match(provided, settings.admin_token):
        raise HTTPException(status_code=403, detail="Jeton d'administration requis")


def allow_rate(key: str, limit: int, window: int = 60) -> bool:
    """Fenêtre glissante. Redis si disponible (plusieurs workers), sinon mémoire process."""
    if limit <= 0:
        return True
    from .cache import _redis

    client = _redis()
    if client is not None:
        with suppress(Exception):
            redis_key = f"riftarium:rl:{key}"
            count = int(client.incr(redis_key))
            if count == 1:
                client.expire(redis_key, window)
            return count <= limit

    now = time.monotonic()
    with _lock:
        bucket = _hits[key]
        cutoff = now - window
        while bucket and bucket[0] <= cutoff:
            bucket.popleft()
        if len(bucket) >= limit:
            return False
        bucket.append(now)
        return True


def limit_auth(request: Request) -> None:
    if not allow_rate(f"auth:{client_ip(request)}", settings.auth_rate_limit):
        raise HTTPException(status_code=429, detail="Trop de tentatives — réessayez dans une minute")


def allowed_image_hosts() -> set[str]:
    hosts = set(DEFAULT_IMAGE_HOSTS)
    if settings.riftarium_env != "prod":
        hosts |= DEV_IMAGE_HOSTS
    for extra in settings.image_hosts.split(","):
        host = extra.strip().lower()
        if host:
            hosts.add(host)
    return hosts


def sanitize_image_url(url: str | None) -> str | None:
    if not url:
        return None
    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.username or parsed.password:
        return None
    host = (parsed.hostname or "").lower()
    if host not in allowed_image_hosts():
        return None
    return url
