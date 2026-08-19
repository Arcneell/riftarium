"""Flux e-mail : vérification d'adresse, réinitialisation de mot de passe, mailer."""

import logging
from datetime import UTC, datetime, timedelta

import app.db as db_module
import pytest
from app import mailer
from app.models import AuthToken
from sqlalchemy import select


def bearer(client):
    token = client.cookies.get("riftarium_session")
    client.cookies.clear()
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def outbox(monkeypatch):
    """Capture les e-mails sortants : liste de tuples (type, destinataire, jeton en clair)."""
    sent = []
    monkeypatch.setattr(mailer, "send_verification_email", lambda to, token: sent.append(("verify", to, token)))
    monkeypatch.setattr(mailer, "send_reset_email", lambda to, token: sent.append(("reset", to, token)))
    return sent


def _expire_all_tokens():
    with db_module.SessionLocal() as session:
        for row in session.scalars(select(AuthToken)).all():
            row.expires_at = datetime.now(UTC) - timedelta(minutes=1)
        session.commit()


# ---------- vérification d'adresse ----------


def test_register_sends_verification_and_verify_flow(client, register_user, outbox):
    assert register_user(client, "verifieur").status_code == 201
    headers = bearer(client)
    assert outbox == [("verify", "verifieur@example.org", outbox[0][2])]

    me = client.get("/api/auth/me", headers=headers).json()
    assert me["email_verified"] is False  # non bloquant : le compte est déjà utilisable

    token = outbox[0][2]
    assert client.post("/api/auth/verify-email", json={"token": token}).status_code == 204
    me = client.get("/api/auth/me", headers=headers).json()
    assert me["email_verified"] is True


def test_verify_email_rejects_invalid_token(client):
    response = client.post("/api/auth/verify-email", json={"token": "nimportequoi"})
    assert response.status_code == 400
    assert "invalide" in response.json()["detail"]


def test_verify_email_rejects_expired_token(client, register_user, outbox):
    register_user(client, "tardif")
    _expire_all_tokens()
    assert client.post("/api/auth/verify-email", json={"token": outbox[0][2]}).status_code == 400


def test_verify_email_token_is_single_use(client, register_user, outbox):
    register_user(client, "unique")
    token = outbox[0][2]
    assert client.post("/api/auth/verify-email", json={"token": token}).status_code == 204
    assert client.post("/api/auth/verify-email", json={"token": token}).status_code == 400


def test_resend_verification(client, register_user, outbox):
    register_user(client, "relance")
    headers = bearer(client)
    first = outbox[0][2]
    assert client.post("/api/auth/resend-verification", headers=headers).status_code == 204
    second = outbox[-1][2]
    assert second != first
    # la nouvelle demande invalide le jeton précédent
    assert client.post("/api/auth/verify-email", json={"token": first}).status_code == 400
    assert client.post("/api/auth/verify-email", json={"token": second}).status_code == 204
    # adresse déjà vérifiée : plus rien à renvoyer
    response = client.post("/api/auth/resend-verification", headers=headers)
    assert response.status_code == 400
    assert "déjà vérifiée" in response.json()["detail"]


def test_resend_verification_requires_auth(client):
    assert client.post("/api/auth/resend-verification").status_code == 401


def test_resend_verification_rate_limited(client, register_user, outbox, monkeypatch):
    from app import security

    monkeypatch.setattr(security.settings, "email_rate_limit", 1)
    register_user(client, "spammeur")
    headers = bearer(client)
    assert client.post("/api/auth/resend-verification", headers=headers).status_code == 204
    assert client.post("/api/auth/resend-verification", headers=headers).status_code == 429


def test_email_change_resets_verification(client, register_user, outbox):
    register_user(client, "migrant")
    headers = bearer(client)
    assert client.post("/api/auth/verify-email", json={"token": outbox[0][2]}).status_code == 204

    response = client.patch(
        "/api/auth/me",
        json={"email": "nouveau@example.org", "current_password": "motdepasse123"},
        headers=headers,
    )
    assert response.status_code == 200
    assert response.json()["email_verified"] is False  # la nouvelle adresse repart non vérifiée
    kind, to, token = outbox[-1]
    assert (kind, to) == ("verify", "nouveau@example.org")
    assert client.post("/api/auth/verify-email", json={"token": token}).status_code == 204
    assert client.get("/api/auth/me", headers=headers).json()["email_verified"] is True


# ---------- réinitialisation de mot de passe ----------


def test_forgot_password_unknown_email_returns_204_without_send(client, outbox):
    response = client.post("/api/auth/forgot-password", json={"email": "fantome@example.org"})
    assert response.status_code == 204  # anti-énumération : même réponse qu'un compte existant
    assert outbox == []


def test_reset_password_full_flow(client, register_user, outbox):
    register_user(client, "oublieux")
    headers = bearer(client)

    assert client.post("/api/auth/forgot-password", json={"email": "oublieux@example.org"}).status_code == 204
    kind, to, token = outbox[-1]
    assert (kind, to) == ("reset", "oublieux@example.org")

    payload = {"token": token, "new_password": "nouveaumdp456"}
    assert client.post("/api/auth/reset-password", json=payload).status_code == 204

    # toutes les sessions existantes sont révoquées (token_version incrémenté)
    assert client.get("/api/auth/me", headers=headers).status_code == 401
    # l'ancien mot de passe ne fonctionne plus, le nouveau oui
    creds = {"email": "oublieux@example.org", "password": "motdepasse123"}
    assert client.post("/api/auth/login", json=creds).status_code == 401
    creds["password"] = "nouveaumdp456"
    assert client.post("/api/auth/login", json=creds).status_code == 200
    # le jeton est consommé : impossible de le rejouer
    assert client.post("/api/auth/reset-password", json=payload).status_code == 400
    with db_module.SessionLocal() as session:
        assert session.scalars(select(AuthToken).where(AuthToken.purpose == "reset")).all() == []


def test_reset_password_rejects_invalid_and_expired_tokens(client, register_user, outbox):
    register_user(client, "presse")
    payload = {"token": "faux-jeton", "new_password": "nouveaumdp456"}
    assert client.post("/api/auth/reset-password", json=payload).status_code == 400
    client.post("/api/auth/forgot-password", json={"email": "presse@example.org"})
    _expire_all_tokens()
    payload["token"] = outbox[-1][2]
    assert client.post("/api/auth/reset-password", json=payload).status_code == 400


def test_new_request_invalidates_previous_reset_token(client, register_user, outbox):
    register_user(client, "insistant")
    client.post("/api/auth/forgot-password", json={"email": "insistant@example.org"})
    client.post("/api/auth/forgot-password", json={"email": "insistant@example.org"})
    first, second = outbox[-2][2], outbox[-1][2]
    stale = {"token": first, "new_password": "nouveaumdp456"}
    fresh = {"token": second, "new_password": "nouveaumdp456"}
    assert client.post("/api/auth/reset-password", json=stale).status_code == 400
    assert client.post("/api/auth/reset-password", json=fresh).status_code == 204


def test_reset_password_enforces_password_rules(client, register_user, outbox):
    register_user(client, "faible")
    client.post("/api/auth/forgot-password", json={"email": "faible@example.org"})
    token = outbox[-1][2]
    # mêmes règles qu'à l'inscription : longueur minimale et mots de passe communs refusés
    assert client.post("/api/auth/reset-password", json={"token": token, "new_password": "court"}).status_code == 422
    weak = {"token": token, "new_password": "password123"}
    assert client.post("/api/auth/reset-password", json=weak).status_code == 422
    # la validation échoue avant consommation : le jeton reste utilisable
    ok = {"token": token, "new_password": "nouveaumdp456"}
    assert client.post("/api/auth/reset-password", json=ok).status_code == 204


def test_forgot_password_rate_limited_per_email(client, register_user, outbox, monkeypatch):
    from app import security

    monkeypatch.setattr(security.settings, "email_rate_limit", 2)
    payload = {"email": "cible@example.org"}
    assert client.post("/api/auth/forgot-password", json=payload).status_code == 204
    assert client.post("/api/auth/forgot-password", json=payload).status_code == 204
    assert client.post("/api/auth/forgot-password", json=payload).status_code == 429


def test_forgot_password_rejects_cross_origin(client):
    response = client.post(
        "/api/auth/forgot-password",
        json={"email": "x@example.org"},
        headers={"Origin": "https://evil.example"},
    )
    assert response.status_code == 403


# ---------- mailer ----------


def test_mailer_console_mode_logs_recipient_and_link(caplog, monkeypatch):
    monkeypatch.setattr(mailer.settings, "smtp_host", "")
    monkeypatch.setattr(mailer.settings, "public_base_url", "http://localhost:8888")
    with caplog.at_level(logging.INFO, logger="riftarium.mailer"):
        mailer.send_verification_email("dev@example.org", "jeton-test")
        mailer.send_reset_email("dev@example.org", "jeton-reset")
    assert "dev@example.org" in caplog.text
    assert "http://localhost:8888/verification-email?token=jeton-test" in caplog.text
    assert "http://localhost:8888/reinitialisation?token=jeton-reset" in caplog.text


class FakeSMTP:
    """Double de smtplib.SMTP / SMTP_SSL : capture logins, STARTTLS et messages."""

    instances = []

    def __init__(self, host, port, timeout=None, context=None):
        self.host, self.port = host, port
        self.tls_started = False
        self.logins = []
        self.sent = []
        FakeSMTP.instances.append(self)

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def starttls(self, context=None):
        self.tls_started = True

    def login(self, user, password):
        self.logins.append((user, password))

    def send_message(self, message):
        self.sent.append(message)


@pytest.fixture()
def smtp_settings(monkeypatch):
    FakeSMTP.instances = []
    monkeypatch.setattr(mailer.settings, "smtp_host", "ssl0.ovh.net")
    monkeypatch.setattr(mailer.settings, "smtp_port", 465)
    monkeypatch.setattr(mailer.settings, "smtp_user", "contact@riftarium.re")
    monkeypatch.setattr(mailer.settings, "smtp_password", "s3cret")
    monkeypatch.setattr(mailer.settings, "mail_from", "Riftarium <contact@riftarium.re>")
    monkeypatch.setattr(mailer.settings, "public_base_url", "https://riftarium.re")
    return monkeypatch


def test_mailer_sends_over_ssl_on_port_465(smtp_settings):
    smtp_settings.setattr(mailer.smtplib, "SMTP_SSL", FakeSMTP)
    mailer.send_reset_email("joueur@example.org", "jeton")
    (smtp,) = FakeSMTP.instances
    assert (smtp.host, smtp.port) == ("ssl0.ovh.net", 465)
    assert smtp.tls_started is False  # SSL implicite : pas de STARTTLS
    assert smtp.logins == [("contact@riftarium.re", "s3cret")]
    (message,) = smtp.sent
    assert message["From"] == "Riftarium <contact@riftarium.re>"
    assert message["To"] == "joueur@example.org"
    assert message["Subject"] == mailer.SUBJECT_RESET
    assert message["Message-ID"].endswith("@riftarium.re>")
    assert message["Date"]
    assert "https://riftarium.re/reinitialisation?token=jeton" in message.get_content()


def test_mailer_uses_starttls_on_other_ports(smtp_settings):
    smtp_settings.setattr(mailer.settings, "smtp_port", 587)
    smtp_settings.setattr(mailer.smtplib, "SMTP", FakeSMTP)
    mailer.send_verification_email("joueur@example.org", "jeton")
    (smtp,) = FakeSMTP.instances
    assert (smtp.host, smtp.port) == ("ssl0.ovh.net", 587)
    assert smtp.tls_started is True
    assert mailer.SUBJECT_VERIFY == smtp.sent[0]["Subject"]


def test_mailer_failure_is_logged_never_raised(smtp_settings, caplog):
    class BrokenSMTP(FakeSMTP):
        def send_message(self, message):
            raise OSError("connexion refusée")

    smtp_settings.setattr(mailer.smtplib, "SMTP_SSL", BrokenSMTP)
    with caplog.at_level(logging.ERROR, logger="riftarium.mailer"):
        mailer.send_email("joueur@example.org", "Sujet", "Corps")  # ne doit pas lever
    assert "échec d'envoi SMTP" in caplog.text
