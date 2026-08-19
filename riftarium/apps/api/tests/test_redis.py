"""Chemins Redis : cache (app/cache.py) et rate limit (app/security.py) avec fakeredis."""

import app.cache as cache_module
import fakeredis
import pytest
import redis
from app import security
from app.cache import cache_clear, cache_get, cache_set


@pytest.fixture()
def fake_redis(monkeypatch):
    server = fakeredis.FakeRedis()
    monkeypatch.setattr(cache_module, "_client", server)
    monkeypatch.setattr(cache_module, "_disabled", False)
    return server


class _BrokenRedis:
    """Client qui explose sur toute commande : simule un Redis tombé après connexion."""

    def __getattr__(self, name):
        def _boom(*args, **kwargs):
            raise redis.ConnectionError("connexion perdue")

        return _boom


# ---------- connexion paresseuse ----------


def test_redis_client_connects_lazily_and_is_reused(monkeypatch):
    server = fakeredis.FakeRedis()
    monkeypatch.setattr(cache_module, "_client", None)
    monkeypatch.setattr(cache_module, "_disabled", False)
    monkeypatch.setattr(cache_module.settings, "redis_url", "redis://redis.test:6379/0")
    monkeypatch.setattr(redis.Redis, "from_url", lambda *args, **kwargs: server)
    assert cache_module._redis() is server
    assert cache_module._redis() is server  # client mémorisé, pas de reconnexion


def test_redis_unreachable_disables_cache(monkeypatch):
    def _refuse(*args, **kwargs):
        raise redis.ConnectionError("refusé")

    monkeypatch.setattr(cache_module, "_client", None)
    monkeypatch.setattr(cache_module, "_disabled", False)
    monkeypatch.setattr(cache_module.settings, "redis_url", "redis://redis.test:6379/0")
    monkeypatch.setattr(redis.Redis, "from_url", _refuse)
    assert cache_module._redis() is None
    assert cache_module._disabled is True  # plus aucune tentative ensuite
    assert cache_get("clef") is None


def test_cache_is_noop_without_redis_url():
    # conftest force REDIS_URL="" : _disabled est vrai, toutes les fonctions sont no-op
    assert cache_module._redis() is None
    assert cache_get("clef") is None
    cache_set("clef", {"a": 1}, ttl=60)
    assert cache_clear("clef") == 0


# ---------- cache_get / cache_set / cache_clear ----------


def test_cache_set_get_roundtrip_with_prefix(fake_redis):
    cache_set("cards:list:p1", {"total": 11, "items": ["a"]}, ttl=300)
    assert cache_get("cards:list:p1") == {"total": 11, "items": ["a"]}
    # les clés sont préfixées « riftarium: » dans Redis
    assert fake_redis.get("riftarium:cards:list:p1") is not None
    assert 0 < fake_redis.ttl("riftarium:cards:list:p1") <= 300


def test_cache_get_missing_or_corrupted_returns_none(fake_redis):
    assert cache_get("cards:absent") is None
    fake_redis.set("riftarium:cards:corrompu", b"{pas du json")
    assert cache_get("cards:corrompu") is None


def test_cache_clear_removes_only_prefix(fake_redis):
    cache_set("cards:a", 1, ttl=60)
    cache_set("cards:b", 2, ttl=60)
    cache_set("sets:list", 3, ttl=60)
    assert cache_clear("cards:") == 2
    assert cache_get("cards:a") is None
    assert cache_get("sets:list") == 3
    assert cache_clear("cards:") == 0  # plus rien à effacer


def test_cache_swallows_redis_errors(monkeypatch):
    monkeypatch.setattr(cache_module, "_client", _BrokenRedis())
    monkeypatch.setattr(cache_module, "_disabled", False)
    cache_set("clef", 1, ttl=60)  # ne lève pas
    assert cache_get("clef") is None
    assert cache_clear("clef") == 0


def test_load_pool_uses_cached_selection(client, fake_redis):
    import app.db as db_module
    from app.deckbuild import load_pool

    with db_module.SessionLocal() as session:
        pool = load_pool(session)
        assert fake_redis.get("riftarium:cards:pool") is not None  # sélection mémorisée
        cached = load_pool(session)  # deuxième appel : requête ciblée sur les ids en cache
        assert [card.id for card in cached] == [card.id for card in pool]

        # cache obsolète (carte disparue) : reconstruction complète
        cache_set("cards:pool", [pool[0].id, "xxx-disparue-000"], ttl=60)
        rebuilt = load_pool(session)
        assert {card.id for card in rebuilt} == {card.id for card in pool}


# ---------- allow_rate, branche Redis ----------


def test_allow_rate_redis_incr_and_threshold(fake_redis):
    assert security.allow_rate("login", 2, window=60) is True
    assert security.allow_rate("login", 2, window=60) is True
    assert security.allow_rate("login", 2, window=60) is False  # 3e requête : au-delà du seuil
    assert security.allow_rate("login", 2, window=60) is False
    assert int(fake_redis.get("riftarium:rl:login")) == 4  # INCR à chaque appel
    assert 0 < fake_redis.ttl("riftarium:rl:login") <= 60
    # la mémoire process n'est pas utilisée quand Redis répond
    assert "login" not in security._hits


def test_allow_rate_redis_reposes_lost_ttl(fake_redis):
    assert security.allow_rate("acct", 5, window=120) is True
    fake_redis.persist("riftarium:rl:acct")  # TTL perdu (process mort entre INCR et EXPIRE)
    assert fake_redis.ttl("riftarium:rl:acct") == -1
    assert security.allow_rate("acct", 5, window=120) is True
    assert 0 < fake_redis.ttl("riftarium:rl:acct") <= 120  # TTL reposé


def test_allow_rate_falls_back_to_memory_when_redis_fails(monkeypatch):
    monkeypatch.setattr(cache_module, "_client", _BrokenRedis())
    monkeypatch.setattr(cache_module, "_disabled", False)
    assert security.allow_rate("fallback", 2, window=60) is True
    assert security.allow_rate("fallback", 2, window=60) is True
    assert security.allow_rate("fallback", 2, window=60) is False  # limite appliquée en mémoire
    assert len(security._hits["fallback"]) == 2


def test_auth_rate_limit_uses_redis_when_available(client, fake_redis, monkeypatch):
    monkeypatch.setattr(security.settings, "auth_rate_limit", 2)
    payload = {"email": "inconnu@example.org", "password": "motdepasse123"}
    headers = {"X-Real-IP": "203.0.113.77"}
    assert client.post("/api/auth/login", json=payload, headers=headers).status_code == 401
    assert client.post("/api/auth/login", json=payload, headers=headers).status_code == 401
    assert client.post("/api/auth/login", json=payload, headers=headers).status_code == 429
    assert int(fake_redis.get("riftarium:rl:auth:203.0.113.77")) == 3
