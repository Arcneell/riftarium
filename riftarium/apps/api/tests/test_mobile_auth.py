"""Authentification du client mobile natif : jeton dans le corps de la réponse.

Le web ne doit rien voir changer (jeton uniquement dans le cookie HttpOnly) ; seul
un appel portant l'en-tête « X-Riftarium-Client: mobile » reçoit le champ `token`.
"""

import jwt
from app.config import settings
from app.routers.auth_routes import MOBILE_CLIENT_HEADER

MOBILE_HEADERS = {MOBILE_CLIENT_HEADER: "mobile"}

CREDENTIALS = {"email": "nyra@example.org", "password": "motdepasse123"}


def _login(client, headers=None):
    return client.post("/api/auth/login", json=CREDENTIALS, headers=headers)


def _exp(token):
    return jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])["exp"]


def test_login_web_sans_entete_ne_renvoie_pas_de_jeton(client, register_user):
    assert register_user(client, "nyra", **CREDENTIALS).status_code == 201
    client.cookies.clear()

    login = _login(client)
    assert login.status_code == 200
    assert "token" not in login.json()  # pas même un « token: null »
    assert login.json()["handle"] == "nyra"
    assert login.cookies.get("riftarium_session")


def test_login_mobile_renvoie_un_jeton_utilisable_en_bearer(client, register_user):
    assert register_user(client, "nyra", **CREDENTIALS).status_code == 201
    client.cookies.clear()

    login = _login(client, MOBILE_HEADERS)
    assert login.status_code == 200
    token = login.json()["token"]
    assert isinstance(token, str) and token
    assert login.cookies.get("riftarium_session")  # le cookie reste posé, comme pour le web

    client.cookies.clear()  # un client natif n'envoie aucun cookie
    me = client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["handle"] == "nyra"


def test_jeton_mobile_expire_bien_plus_tard_que_le_jeton_web(client, register_user):
    assert register_user(client, "nyra", **CREDENTIALS).status_code == 201
    client.cookies.clear()

    web = _login(client)
    token_web = web.cookies.get("riftarium_session")
    client.cookies.clear()
    token_mobile = _login(client, MOBILE_HEADERS).json()["token"]

    ecart_minimal = (settings.jwt_ttl_hours_mobile - settings.jwt_ttl_hours - 1) * 3600
    assert _exp(token_mobile) - _exp(token_web) >= ecart_minimal


def test_inscription_mobile_et_web(client, register_user):
    mobile = register_user(client, "nyra", headers=MOBILE_HEADERS)
    assert mobile.status_code == 201
    assert mobile.json()["token"]

    client.cookies.clear()
    web = register_user(client, "lyandre")
    assert web.status_code == 201
    assert "token" not in web.json()


def test_entete_insensible_a_la_casse_et_autre_valeur_ignoree(client, register_user):
    assert register_user(client, "nyra", **CREDENTIALS).status_code == 201
    client.cookies.clear()

    casse = _login(client, {MOBILE_CLIENT_HEADER: " Mobile "})
    assert casse.status_code == 200
    assert casse.json()["token"]

    client.cookies.clear()
    autre = _login(client, {MOBILE_CLIENT_HEADER: "web"})
    assert autre.status_code == 200
    assert "token" not in autre.json()


def test_changement_de_mot_de_passe_revoque_le_jeton_mobile(client, register_user):
    assert register_user(client, "nyra", **CREDENTIALS).status_code == 201
    client.cookies.clear()

    token = _login(client, MOBILE_HEADERS).json()["token"]
    bearer = {"Authorization": f"Bearer {token}"}
    client.cookies.clear()

    change = client.post(
        "/api/auth/password",
        json={"current_password": CREDENTIALS["password"], "new_password": "nouveausecret"},
        headers=bearer,
    )
    assert change.status_code == 200
    assert "token" not in change.json()  # réponse web inchangée sur cette route

    client.cookies.clear()
    assert client.get("/api/auth/me", headers=bearer).status_code == 401  # token_version incrémenté
