import jwt
from app.auth import hash_password, verify_password
from app.config import WEAK_JWT_SECRETS, Settings, settings, validate_production_settings
from app.security import sanitize_image_url, tokens_match


def test_cookie_session_roundtrip(client):
    created = client.post(
        "/api/auth/register",
        json={
            "handle": "cookieuser",
            "email": "cookie@example.org",
            "password": "motdepasse123",
            "accept_terms": True,
            "confirm_age": True,
        },
    )
    assert created.status_code == 201
    assert "riftarium_session" in created.cookies
    me = client.get("/api/auth/me")
    assert me.status_code == 200
    assert me.json()["handle"] == "cookieuser"

    token = created.json()["token"]
    logged_out = client.post("/api/auth/logout")
    assert logged_out.status_code == 204
    assert client.get("/api/auth/me").status_code == 401
    assert client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"}).status_code == 401


def test_jwt_without_version_is_rejected(client, auth):
    forged = jwt.encode({"sub": "1", "handle": "testeur"}, settings.jwt_secret, algorithm="HS256")
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
