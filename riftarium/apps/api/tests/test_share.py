"""Aperçu social d'un deck : image Open Graph et page de méta pour les robots."""

from io import BytesIO

import app.og as og
import pytest
from PIL import Image

from test_api import deck_payload


@pytest.fixture(autouse=True)
def no_network(monkeypatch):
    """Aucun appel au CDN pendant les tests : illustration synthétique, cache remis à zéro."""
    calls = {"count": 0}

    def fake_fetch(url):
        calls["count"] += 1
        return Image.new("RGB", (400, 560), (60, 40, 30)) if url else None

    monkeypatch.setattr(og, "_fetch_art", fake_fetch)
    og.clear_cache()
    yield calls
    og.clear_cache()


def public_deck(client, auth, **overrides):
    response = client.post("/api/decks", json=deck_payload(**overrides), headers=auth)
    assert response.status_code == 201, response.text
    return response.json()


def test_og_image_is_a_1200x630_png(client, auth):
    deck = public_deck(client, auth)
    response = client.get(f"/api/decks/{deck['id']}/og.png")

    assert response.status_code == 200
    assert response.headers["content-type"] == "image/png"
    assert "max-age" in response.headers["cache-control"]
    assert response.content[:8] == b"\x89PNG\r\n\x1a\n"
    assert Image.open(BytesIO(response.content)).size == (1200, 630)


def test_og_image_is_cached_between_calls(client, auth, no_network):
    deck = public_deck(client, auth)
    first = client.get(f"/api/decks/{deck['id']}/og.png").content
    second = client.get(f"/api/decks/{deck['id']}/og.png").content

    assert first == second
    assert no_network["count"] == 1  # l'illustration n'est téléchargée qu'une fois


def test_og_image_refused_for_a_private_deck(client, auth):
    deck = public_deck(client, auth, name="Brouillon privé", is_public=False)

    assert client.get(f"/api/decks/{deck['id']}/og.png").status_code == 404
    assert client.get("/api/decks/999999/og.png").status_code == 404


def test_preview_exposes_open_graph_meta(client, auth):
    deck = public_deck(client, auth, name="Fureur du Nord", description="Aggro turn 2.")
    response = client.get(f"/api/decks/{deck['id']}/preview")

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/html")
    body = response.text
    assert f'property="og:image" content="http://localhost:8888/api/decks/{deck["id"]}/og.png"' in body
    assert "Fureur du Nord" in body
    assert "Aggro turn 2." in body
    assert 'name="twitter:card" content="summary_large_image"' in body
    assert 'name="robots" content="noindex, nofollow"' in body  # bêta fermée
    assert f'href="http://localhost:8888/decks/{deck["id"]}"' in body


def test_preview_escapes_the_deck_name(client, auth):
    deck = public_deck(client, auth, name='Deck "Fureur" <script>')
    body = client.get(f"/api/decks/{deck['id']}/preview").text

    assert "<script>" not in body
    assert "&lt;script&gt;" in body
    assert "&quot;Fureur&quot;" in body


def test_preview_of_a_private_deck_stays_generic(client, auth):
    deck = public_deck(client, auth, name="Liste secrète", is_public=False)
    body = client.get(f"/api/decks/{deck['id']}/preview").text

    assert "Liste secrète" not in body
    assert "Riftarium — Cartes, decks et règles Riftbound" in body
    assert client.get("/api/decks/999999/preview").status_code == 200


def test_summary_falls_back_on_deck_facts(client, auth):
    deck = public_deck(client, auth, name="Sans description", description="")
    body = client.get(f"/api/decks/{deck['id']}/preview").text

    assert "Deck légal de testeur" in body
    assert "légende Daughter of the Void" in body
    assert "21 cartes" in body


def test_og_image_survives_a_missing_illustration(client, auth, monkeypatch):
    monkeypatch.setattr(og, "_fetch_art", lambda url: None)
    deck = public_deck(client, auth, name="Sans illustration")
    response = client.get(f"/api/decks/{deck['id']}/og.png")

    assert response.status_code == 200
    assert Image.open(BytesIO(response.content)).size == (1200, 630)
