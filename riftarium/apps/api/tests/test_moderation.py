"""Modération lexicale V2 : mots entiers, fragments, normalisation, faux positifs."""

from app.moderation import review


def test_short_insults_match_whole_words_only():
    # « con » bloqué en mot entier…
    assert review("con") == "pending"
    assert review("Con") == "pending"
    assert review("mon deck de con") == "pending"
    assert review("espèce de con !") == "pending"
    # … mais jamais à l'intérieur d'un mot légitime.
    assert review("concombre géant") == "published"
    assert review("console de jeu") == "published"
    assert review("construction du deck") == "published"
    assert review("dracon des abysses") == "published"


def test_no_false_positives_on_legitimate_words():
    # Chaque mot contient un terme interdit en sous-chaîne : aucun ne doit matcher.
    for text in [
        "salopette rouge",  # salope
        "computer science",  # pute
        "député de la Faille",  # pute (après pliage des accents)
        "calcul de dégâts",  # cul
        "orbite lunaire",  # bite
        "habite à Piltover",  # bite
        "thérapiste du désert",  # rape
        "grape and drapes",  # rape
        "classe et passion",  # ass
        "chattemite",  # chatte (mot entier seulement)
        "association de joueurs",  # ass
    ]:
        assert review(text) == "published", text


def test_french_insults_and_slurs():
    for text in ["putain de deck", "fils de pute", "sale con", "nique ta mère", "gros pédé", "TG"]:
        assert review(text) == "pending", text


def test_english_insults_and_slurs():
    for text in ["fuck this game", "what a bitch", "you retarded", "dumbass deck", "kill yourself", "fUcK"]:
        assert review(text) == "pending", text


def test_fragments_catch_embedded_terms():
    assert review("xXconnardXx") == "pending"
    assert review("supermotherfucker3000") == "pending"
    assert review("bigasshole") == "pending"


def test_normalisation_still_applies():
    assert review("c.o.n") == "pending"  # lettres épelées
    assert review("s a l o p e") == "pending"
    assert review("c0nnard") == "pending"  # leet
    assert review("соn") == "pending"  # « с » et « о » cyrilliques
    assert review("PUTAIN") == "pending"
    assert review("niquetamere") == "pending"  # expression recollée


def test_scam_terms_still_blocked():
    assert review("paiement via paypal.me/xyz") == "pending"
    assert review("western union uniquement") == "pending"


def test_clean_content_published():
    assert review("") == "published"
    assert review("Fureur de Noxus, aggro runes rouges") == "published"
    assert review("Contrôle Calme/Esprit, mulligan agressif") == "published"


def test_handle_moderation_on_register(client):
    payload = {
        "handle": "connard88",
        "email": "modo-handle@example.com",
        "password": "Xk9#vLm2pQ7w",
        "accept_terms": True,
        "confirm_age": True,
    }
    response = client.post("/api/auth/register", json=payload)
    assert response.status_code == 422
    assert "pseudo" in response.json()["detail"]


def test_handle_moderation_on_profile_change(client, auth):
    response = client.patch(
        "/api/auth/me",
        headers=auth,
        json={"handle": "fdp-du-42", "current_password": "motdepasse123"},
    )
    assert response.status_code == 422
    assert "pseudo" in response.json()["detail"]


def test_deck_named_con_goes_pending(client, auth):
    created = client.post("/api/decks", headers=auth, json={"name": "con", "is_public": True})
    assert created.status_code in (200, 201)
    assert created.json()["moderation_status"] == "pending"
