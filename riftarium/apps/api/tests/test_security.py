from datetime import UTC, datetime, timedelta

import jwt
from app.auth import hash_password, verify_password
from app.config import WEAK_JWT_SECRETS, Settings, settings, validate_production_settings
from app.security import sanitize_image_url, tokens_match


def test_cookie_session_roundtrip(client, register_user):
    created = register_user(client, "cookieuser", email="cookie@example.org")
    assert created.status_code == 201
    assert "riftarium_session" in created.cookies
    assert "token" not in created.json()  # le jeton ne circule que via le cookie HttpOnly
    me = client.get("/api/auth/me")
    assert me.status_code == 200
    assert me.json()["handle"] == "cookieuser"

    token = created.cookies.get("riftarium_session")
    logged_out = client.post("/api/auth/logout")
    assert logged_out.status_code == 204
    assert client.get("/api/auth/me").status_code == 401  # ce navigateur est déconnecté (cookie effacé)
    # ... mais les sessions des autres appareils restent valides (pas de révocation globale au logout)
    assert client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"}).status_code == 200


def test_change_password_revokes_other_sessions(client, auth):
    changed = client.post(
        "/api/auth/password",
        json={"current_password": "motdepasse123", "new_password": "nouveausecret"},
        headers=auth,
    )
    assert changed.status_code == 200
    # l'ancien jeton (autre appareil) est révoqué par l'incrément de token_version
    assert client.get("/api/auth/me", headers=auth).status_code == 401


def test_jwt_without_version_is_rejected(client, auth):
    forged = jwt.encode({"sub": "1", "handle": "testeur"}, settings.jwt_secret, algorithm="HS256")
    assert client.get("/api/auth/me", headers={"Authorization": f"Bearer {forged}"}).status_code == 401


def test_expired_jwt_is_rejected(client, auth):
    # jeton valide par ailleurs (sub/ver corrects) mais expiré depuis une heure
    expired = jwt.encode(
        {"sub": "1", "handle": "testeur", "ver": 1, "exp": datetime.now(UTC) - timedelta(hours=1)},
        settings.jwt_secret,
        algorithm="HS256",
    )
    response = client.get("/api/auth/me", headers={"Authorization": f"Bearer {expired}"})
    assert response.status_code == 401
    assert response.json()["detail"] == "Jeton invalide ou expiré"
    # contrôle : le même payload non expiré passe
    valid = jwt.encode(
        {"sub": "1", "handle": "testeur", "ver": 1, "exp": datetime.now(UTC) + timedelta(hours=1)},
        settings.jwt_secret,
        algorithm="HS256",
    )
    assert client.get("/api/auth/me", headers={"Authorization": f"Bearer {valid}"}).status_code == 200


def test_jwt_with_garbage_subject_is_rejected(client, auth):
    future = datetime.now(UTC) + timedelta(hours=1)
    for sub in ("pas-un-id", "999999"):
        forged = jwt.encode({"sub": sub, "ver": 1, "exp": future}, settings.jwt_secret, algorithm="HS256")
        assert client.get("/api/auth/me", headers={"Authorization": f"Bearer {forged}"}).status_code == 401


def test_password_compare_digest_accepts_valid_hash():
    stored = hash_password("motdepasse123")
    assert verify_password("motdepasse123", stored) is True
    assert verify_password("autrechose", stored) is False
    assert verify_password("motdepasse123", "pas-un-hash") is False


def test_auth_rate_limit(client, monkeypatch):
    from app import security

    monkeypatch.setattr(security.settings, "auth_rate_limit", 2)
    payload = {"email": "inconnu@example.org", "password": "motdepasse123"}
    headers = {"X-Real-IP": "203.0.113.50"}
    assert client.post("/api/auth/login", json=payload, headers=headers).status_code == 401
    assert client.post("/api/auth/login", json=payload, headers=headers).status_code == 401
    blocked = client.post("/api/auth/login", json=payload, headers=headers)
    assert blocked.status_code == 429


def test_sanitize_image_url_allowlist(monkeypatch):
    from app import security

    monkeypatch.setattr(security.settings, "riftarium_env", "prod")
    monkeypatch.setattr(security.settings, "image_hosts", "")
    riot = "https://cmsassets.rgpub.io/sanity/images/dsfx7636/card.png"
    assert sanitize_image_url(riot) == riot
    assert sanitize_image_url("https://cdn.example/ahri.png") is None
    assert sanitize_image_url("http://cmsassets.rgpub.io/x.png") is None
    assert sanitize_image_url("https://evil.example/x.png") is None
    assert sanitize_image_url("https://user:pass@cmsassets.rgpub.io/x.png") is None  # credentials interdits
    # hôtes supplémentaires configurés via IMAGE_HOSTS (les entrées vides sont ignorées)
    monkeypatch.setattr(security.settings, "image_hosts", "cdn.custom, ,AUTRE.example")
    assert sanitize_image_url("https://cdn.custom/x.png") == "https://cdn.custom/x.png"
    assert sanitize_image_url("https://autre.example/x.png") == "https://autre.example/x.png"
    monkeypatch.setattr(security.settings, "image_hosts", "")
    monkeypatch.setattr(security.settings, "riftarium_env", "test")
    assert sanitize_image_url("https://cdn.example/ahri.png") == "https://cdn.example/ahri.png"


def test_production_settings_reject_weak_secrets(monkeypatch):
    from app import config

    monkeypatch.setattr(config.settings, "riftarium_env", "prod")
    monkeypatch.setattr(config.settings, "jwt_secret", "dev-secret-change-me")
    monkeypatch.setattr(config.settings, "admin_token", "")
    try:
        validate_production_settings()
        raise AssertionError("expected RuntimeError")
    except RuntimeError:
        pass
    monkeypatch.setattr(config.settings, "jwt_secret", "a-sufficiently-long-production-secret")
    monkeypatch.setattr(config.settings, "admin_token", "short")
    try:
        validate_production_settings()
        raise AssertionError("expected RuntimeError")
    except RuntimeError:
        pass
    monkeypatch.setattr(config.settings, "admin_token", "admin-token-16ch")
    validate_production_settings()
    assert "test-secret" in WEAK_JWT_SECRETS
    assert Settings(riftarium_env="prod").is_prod is True
    assert Settings(riftarium_env="prod").expose_docs is False


def test_client_ip_uses_real_ip_not_forwarded_for():
    from types import SimpleNamespace

    from app.security import client_ip

    request = SimpleNamespace(
        headers={"x-real-ip": "203.0.113.9", "x-forwarded-for": "8.8.8.8, 10.0.0.1"},
        client=SimpleNamespace(host="172.18.0.4"),
    )
    assert client_ip(request) == "203.0.113.9"
    bare = SimpleNamespace(headers={}, client=SimpleNamespace(host="172.18.0.4"))
    assert client_ip(bare) == "172.18.0.4"


def test_admin_token_comparison_rejects_empty():
    assert tokens_match(None, "abc") is False
    assert tokens_match("abc", None) is False
    assert tokens_match("abc", "abc") is True
    assert tokens_match("abc", "xyz") is False


def test_moderation_folds_leet(client, auth):
    payload = {"name": "c0nnard", "description": "", "format": "free", "cards": []}
    deck = client.post("/api/decks", json=payload, headers=auth).json()
    assert deck["moderation_status"] == "pending"


def test_docs_available_outside_prod(client):
    assert client.get("/docs").status_code == 200
    assert client.get("/openapi.json").status_code == 200


def test_register_race_integrity_error_returns_409(client, monkeypatch, register_user):
    from app.routers import auth_routes

    assert register_user(client, "doublon").status_code == 201
    # simule la course check-then-insert : la pré-vérification ne voit pas le doublon
    monkeypatch.setattr(auth_routes, "_account_conflict", lambda db, handle, email: False)
    assert register_user(client, "doublon").status_code == 409


def test_login_rehashes_weaker_scrypt_params(client, monkeypatch):
    import app.db as db_module
    from app import auth as auth_module
    from app.models import User
    from sqlalchemy import select

    # hash produit avec des paramètres plus faibles que la cible de test (n=1024 < 4096)
    monkeypatch.setattr(auth_module.settings, "scrypt_n", 1024)
    weak_hash = auth_module.hash_password("motdepasse123")
    monkeypatch.undo()
    assert weak_hash.startswith("1024$")

    with db_module.SessionLocal() as session:
        session.add(User(handle="ancien", email="ancien@example.org", password_hash=weak_hash, token_version=1))
        session.commit()

    login = client.post("/api/auth/login", json={"email": "ancien@example.org", "password": "motdepasse123"})
    assert login.status_code == 200

    with db_module.SessionLocal() as session:
        user = session.scalar(select(User).where(User.email == "ancien@example.org"))
        assert user.password_hash.startswith("4096$")  # re-hash transparent vers la cible
        assert verify_password("motdepasse123", user.password_hash)

    # une nouvelle connexion ne re-hashe plus (paramètres déjà à la cible)
    assert (
        client.post("/api/auth/login", json={"email": "ancien@example.org", "password": "motdepasse123"}).status_code
        == 200
    )


def test_legacy_hash_format_still_verifies():
    import hashlib
    import os as os_module

    salt = os_module.urandom(16)
    digest = hashlib.scrypt(b"motdepasse123", salt=salt, n=2**14, r=8, p=1, maxmem=64 * 1024 * 1024)
    legacy = salt.hex() + "$" + digest.hex()
    assert verify_password("motdepasse123", legacy) is True
    assert verify_password("autrechose", legacy) is False

    from app.auth import needs_rehash

    # en config de test (n=4096), l'ancien format (n=16384) n'est pas plus faible : pas de re-hash
    assert needs_rehash(legacy) is False


def test_auth_account_rate_limit(client, monkeypatch):
    from app import security

    monkeypatch.setattr(security.settings, "auth_account_rate_limit", 2)
    payload = {"email": "cible@example.org", "password": "motdepasse123"}
    # IPs différentes : seule la limite par compte peut bloquer
    assert client.post("/api/auth/login", json=payload, headers={"X-Real-IP": "198.51.100.1"}).status_code == 401
    assert client.post("/api/auth/login", json=payload, headers={"X-Real-IP": "198.51.100.2"}).status_code == 401
    blocked = client.post("/api/auth/login", json=payload, headers={"X-Real-IP": "198.51.100.3"})
    assert blocked.status_code == 429
    # un autre compte n'est pas affecté
    other = client.post(
        "/api/auth/login",
        json={"email": "autre-cible@example.org", "password": "motdepasse123"},
        headers={"X-Real-IP": "198.51.100.4"},
    )
    assert other.status_code == 401


def test_cross_origin_auth_requests_are_rejected(client, auth, register_user):
    payload = {"email": "testeur@example.org", "password": "motdepasse123"}
    evil = client.post("/api/auth/login", json=payload, headers={"Origin": "https://evil.example"})
    assert evil.status_code == 403
    fetched = client.post("/api/auth/login", json=payload, headers={"Sec-Fetch-Site": "cross-site"})
    assert fetched.status_code == 403
    opaque = client.post("/api/auth/login", json=payload, headers={"Origin": "null"})
    assert opaque.status_code == 403  # origine opaque (sandbox, data:) : refusée aussi
    same_origin = client.post("/api/auth/login", json=payload, headers={"Origin": "http://testserver"})
    assert same_origin.status_code == 200
    register = register_user(client, "intrusweb", headers={"Origin": "https://evil.example"})
    assert register.status_code == 403


def test_common_passwords_are_rejected(client, auth, register_user):
    assert register_user(client, "faible", password="azertyuiop").status_code == 422
    assert register_user(client, "faible", password="Password123").status_code == 422
    changed = client.post(
        "/api/auth/password",
        json={"current_password": "motdepasse123", "new_password": "123456789"},
        headers=auth,
    )
    assert changed.status_code == 422


def test_client_ip_without_client_defaults_to_zero():
    from types import SimpleNamespace

    from app.security import client_ip

    assert client_ip(SimpleNamespace(headers={}, client=None)) == "0"
    assert client_ip(SimpleNamespace(headers={"x-real-ip": " , "}, client=None)) == "0"


def test_allow_rate_zero_limit_always_allows():
    from app.security import allow_rate

    assert allow_rate("libre", 0) is True
    assert allow_rate("libre", -1) is True


def test_allow_rate_memory_purges_stale_buckets():
    import time
    from collections import deque

    from app import security

    now = time.monotonic()
    security._hits["fantome"] = deque([now - security._PURGE_HORIZON - 1])
    security._last_purge = 0.0
    assert security.allow_rate("vivant", 5) is True
    assert "fantome" not in security._hits  # deque morte purgée
    assert "vivant" in security._hits


def test_allow_rate_memory_window_slides(monkeypatch):
    import itertools

    from app import security

    clock = itertools.count(start=1000, step=61).__next__  # chaque appel avance de 61 s
    monkeypatch.setattr(security.time, "monotonic", lambda: float(clock()))
    assert security.allow_rate("glisse", 1, window=60) is True
    # 61 s plus tard : l'entrée précédente est sortie de la fenêtre
    assert security.allow_rate("glisse", 1, window=60) is True


def test_verify_password_rejects_malformed_hashes():
    assert verify_password("x", "zz$pas-du-hex") is False  # hex invalide
    assert verify_password("x", "a$b$c$d$e") is False  # champs numériques invalides

    from app.auth import needs_rehash

    assert needs_rehash("pas-un-hash") is False


def test_moderation_catches_spaced_and_homoglyph_variants():
    from app.moderation import review

    assert review("connard") == "pending"
    assert review("c o n n a r d") == "pending"
    assert review("c.o.n.n.a.r.d") == "pending"
    assert review("сonnard") == "pending"  # premier « с » cyrillique
    assert review("Deck contrôle Fureur, plan de jeu classique") == "published"
    assert review("Liste de tournoi retravaillée à la table") == "published"
