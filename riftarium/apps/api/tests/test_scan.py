"""Scan mobile : dHash des visuels, index public des empreintes, recalcul admin.

Le matching se fait côté client : le serveur ne fait que calculer les empreintes
(depuis le CDN, via l'endpoint admin) et exposer l'index compact.
"""

from io import BytesIO

import app.db as db_module
import app.main as main_module
import httpx
import pytest
import respx
from app.imagehash import dhash_hex, hamming_hex
from app.models import Card
from app.sync import _upsert_card
from PIL import Image

ADMIN = {"X-Admin-Token": "test-admin-token-ok"}


# ---------------------------------------------------------------------------
# Images synthétiques déterministes
# ---------------------------------------------------------------------------


def png_bytes(image):
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def gradient_png(horizontal=True, size=64, reverse=False):
    """Dégradé linéaire en niveaux de gris (croissant, ou décroissant avec reverse)."""
    image = Image.new("L", (size, size))
    values = []
    for y in range(size):
        for x in range(size):
            t = x if horizontal else y
            level = round(t * 255 / (size - 1))
            values.append(255 - level if reverse else level)
    image.putdata(values)
    return png_bytes(image)


def checkerboard_png(size=64, square=8):
    image = Image.new("L", (size, size))
    image.putdata([255 if ((x // square + y // square) % 2 == 0) else 0 for y in range(size) for x in range(size)])
    return png_bytes(image)


def scan_card(card_id, image_url=None, image_hash=None):
    """Carte minimale supplémentaire pour les tests de recalcul."""
    return Card(
        id=card_id,
        riftbound_id=card_id,
        name=f"Scan {card_id}",
        set_id="OGN",
        type="Unit",
        collector_number=900,
        image_url=image_url,
        image_hash=image_hash,
    )


# ---------------------------------------------------------------------------
# dHash unitaire
# ---------------------------------------------------------------------------


def test_dhash_length_and_stability():
    digest = dhash_hex(checkerboard_png())
    assert len(digest) == 128
    assert set(digest) <= set("0123456789abcdef")
    assert dhash_hex(checkerboard_png()) == digest  # même image → même empreinte


def test_dhash_gradient_bits_follow_spec():
    # Un dégradé linéaire recadré (fenêtre d'art) reste un dégradé linéaire : les
    # valeurs exactes restent celles de la spec.
    # Dégradé croissant : aucun pixel plus clair que son voisin de droite/du bas → 512 bits à 0.
    assert dhash_hex(gradient_png(horizontal=True)) == "0" * 128
    # Dégradé horizontal décroissant : les 256 bits H à 1, les 256 bits V à 0 (H d'abord).
    assert dhash_hex(gradient_png(horizontal=True, reverse=True)) == "f" * 64 + "0" * 64
    # Dégradé vertical décroissant : symétrique (V ensuite).
    assert dhash_hex(gradient_png(horizontal=False, reverse=True)) == "0" * 64 + "f" * 64


def card_like_png(art_seed=0, text_seed=0, size=100):
    """Carte simulée : fenêtre d'art en haut, bande de texte imprimé sous y = 54 %.

    Avec size=100, le crop (6 %→94 %, 6 %→54 %) couvre les lignes 6 à 53 :
    tout ce qui est à y ≥ 54 est hors fenêtre d'art.
    """
    image = Image.new("L", (size, size))
    pixels = []
    for y in range(size):
        for x in range(size):
            if y >= 54:  # bande basse : texte (dépend de la langue de la carte physique)
                pixels.append((x * 7 + y * 13 + text_seed * 31) % 256)
            else:  # fenêtre d'illustration (identique dans toutes les langues)
                pixels.append((x * 11 + y * 5 + art_seed * 17) % 256)
    image.putdata(pixels)
    return png_bytes(image)


def test_dhash_ignores_text_band_but_reads_art_window():
    base = dhash_hex(card_like_png())
    # Même illustration, texte différent (carte FR vs EN) → même empreinte.
    assert dhash_hex(card_like_png(text_seed=1)) == base
    # Illustration différente → empreinte différente.
    assert dhash_hex(card_like_png(art_seed=1)) != base


def test_dhash_differs_between_images():
    gradient = dhash_hex(gradient_png(horizontal=True, reverse=True))
    checker = dhash_hex(checkerboard_png())
    assert gradient != checker
    assert hamming_hex(gradient, checker) > 64  # images très différentes → distance franche


def test_dhash_accepts_color_images():
    image = Image.new("RGB", (32, 32))
    image.putdata([(x * 8, 0, y * 8) for y in range(32) for x in range(32)])
    assert len(dhash_hex(png_bytes(image))) == 128


def test_hamming_hex():
    assert hamming_hex("0" * 128, "0" * 128) == 0
    assert hamming_hex("f" * 128, "0" * 128) == 512
    assert hamming_hex("00", "01") == 1
    with pytest.raises(ValueError):
        hamming_hex("00", "0000")


# ---------------------------------------------------------------------------
# GET /api/cards/hashes
# ---------------------------------------------------------------------------


def test_cards_hashes_lists_every_card_even_without_hash(client):
    """La voie « lecture du code » n'a besoin que de rid : aucune carte n'est omise."""
    response = client.get("/api/cards/hashes")
    assert response.status_code == 200
    payload = response.json()
    assert payload["algo"] == "dhash16-hv-art"
    assert payload["count"] == len(payload["items"]) > 0
    # Aucune empreinte calculée dans le seed : h est null partout, rid toujours renseigné.
    assert all(item["h"] is None and item["rid"] for item in payload["items"])
    # Les variantes se distinguent par leur rid (étoile, lettre) : le client en a besoin.
    rids = {item["rid"] for item in payload["items"]}
    assert {"ogn-037-298", "ogn-037a-298", "ogn-037*-298"} <= rids


def test_cards_hashes_cache_headers(client):
    response = client.get("/api/cards/hashes")
    assert response.headers["Cache-Control"] == "public, max-age=3600"
    assert response.headers["Vary"] == "Authorization, Cookie"


def test_cards_hashes_cache_key_is_versioned(client, monkeypatch):
    """Le format a changé (rid, cartes sans empreinte). L'entrée Redis « cards:hashes »
    d'avant le déploiement survit 6 h : la servir priverait le nouveau client de rid —
    plus de lecture de code, et un regroupement par variante qui s'effondre. La clé
    versionnée est le seul garde-fou (Redis n'est pas recréé au déploiement)."""
    import app.routers.cards as cards_module

    lus, ecrits = [], []
    monkeypatch.setattr(cards_module, "cache_get", lambda key: lus.append(key) or None)
    monkeypatch.setattr(cards_module, "cache_set", lambda key, value, ttl: ecrits.append(key))

    payload = client.get("/api/cards/hashes").json()
    assert payload["count"] > 0
    # Ni lecture ni écriture sur l'ancienne clé : le vieux payload reste ignoré jusqu'à son TTL.
    assert "cards:hashes:v2" in lus and "cards:hashes" not in lus
    assert ecrits == ["cards:hashes:v2"]
    # Le préfixe « cards: » reste celui qu'invalident la sync et le recalcul admin.
    assert all(key.startswith("cards:") for key in ecrits)


def test_cards_hashes_serves_hash_and_rid_side_by_side(client):
    digest = dhash_hex(checkerboard_png())
    with db_module.SessionLocal() as session:
        session.get(Card, "ogn-247-298").image_hash = digest
        session.commit()

    payload = client.get("/api/cards/hashes").json()
    assert payload["algo"] == "dhash16-hv-art"
    assert payload["count"] == len(payload["items"])
    items = {item["id"]: item for item in payload["items"]}
    assert items["ogn-247-298"] == {"id": "ogn-247-298", "rid": "ogn-247-298", "h": digest}
    # Les cartes sans empreinte restent listées (h null) : elles restent identifiables par leur code.
    assert items["ogn-275-298"]["h"] is None


# ---------------------------------------------------------------------------
# POST /api/admin/cards/hashes
# ---------------------------------------------------------------------------


def test_admin_hashes_requires_admin_token(client):
    assert client.post("/api/admin/cards/hashes").status_code == 403
    assert client.post("/api/admin/cards/hashes", headers={"X-Admin-Token": "nope"}).status_code == 403


@respx.mock
def test_admin_hashes_computes_and_tolerates_per_card_errors(client):
    image = checkerboard_png()
    # Seule carte du seed avec un visuel : ogn-247-298 (cdn.example, hôte de dev autorisé).
    respx.get("https://cdn.example/ahri-legend.png").mock(return_value=httpx.Response(200, content=image))
    respx.get("https://cdn.example/introuvable.png").mock(return_value=httpx.Response(404))
    respx.get("https://cdn.example/corrompue.png").mock(return_value=httpx.Response(200, content=b"pas une image"))
    with db_module.SessionLocal() as session:
        session.add(scan_card("scan-404", image_url="https://cdn.example/introuvable.png"))
        session.add(scan_card("scan-corrompue", image_url="https://cdn.example/corrompue.png"))
        # Hôte hors allow-list : jamais téléchargé (respx échouerait sur une requête non mockée).
        session.add(scan_card("scan-interdit", image_url="https://pas-autorise.example/x.png"))
        session.commit()

    response = client.post("/api/admin/cards/hashes", headers=ADMIN)
    assert response.status_code == 200
    # 3 échecs (404, image invalide, hôte interdit) restent recalculables : comptés dans remaining.
    assert response.json() == {"computed": 1, "failed": 3, "remaining": 3}

    with db_module.SessionLocal() as session:
        assert session.get(Card, "ogn-247-298").image_hash == dhash_hex(image)
        assert session.get(Card, "scan-404").image_hash is None

    # L'index public reflète immédiatement l'empreinte calculée.
    items = {item["id"]: item for item in client.get("/api/cards/hashes").json()["items"]}
    assert items["ogn-247-298"]["h"] == dhash_hex(image)
    assert items["scan-404"]["h"] is None


@respx.mock
def test_admin_hashes_bounded_per_call(client, monkeypatch):
    monkeypatch.setattr(main_module, "HASH_BATCH_SIZE", 2)
    image = gradient_png(reverse=True)
    respx.get(url__regex=r"https://cdn\.example/.*\.png").mock(return_value=httpx.Response(200, content=image))
    with db_module.SessionLocal() as session:
        for index in range(3):  # + ogn-247-298 du seed = 4 cartes candidates
            session.add(scan_card(f"scan-{index}", image_url=f"https://cdn.example/scan-{index}.png"))
        session.commit()

    first = client.post("/api/admin/cards/hashes", headers=ADMIN).json()
    assert first == {"computed": 2, "failed": 0, "remaining": 2}
    second = client.post("/api/admin/cards/hashes", headers=ADMIN).json()
    assert second == {"computed": 2, "failed": 0, "remaining": 0}
    third = client.post("/api/admin/cards/hashes", headers=ADMIN).json()  # plus rien à faire
    assert third == {"computed": 0, "failed": 0, "remaining": 0}

    hashed = [item for item in client.get("/api/cards/hashes").json()["items"] if item["h"]]
    assert len(hashed) == 4
    assert all(item["h"] == dhash_hex(image) for item in hashed)


# ---------------------------------------------------------------------------
# Sync : invalidation de l'empreinte
# ---------------------------------------------------------------------------


def sync_payload(image_url):
    return {
        "id": "scan-sync",
        "riftbound_id": "scan-sync",
        "name": "Carte scannable",
        "collector_number": 901,
        "classification": {"type": "Unit"},
        "media": {"image_url": image_url},
        "set": {"set_id": "ogn"},
    }


def test_sync_new_card_has_no_hash(client):
    with db_module.SessionLocal() as session:
        _upsert_card(session, sync_payload("https://cdn.example/v1.png"))
        session.commit()
        assert session.get(Card, "scan-sync").image_hash is None


def test_sync_invalidates_hash_only_when_image_url_changes(client):
    with db_module.SessionLocal() as session:
        _upsert_card(session, sync_payload("https://cdn.example/v1.png"))
        session.commit()
        session.get(Card, "scan-sync").image_hash = "ab" * 64
        session.commit()

        # Même visuel : l'empreinte (coûteuse à recalculer) est conservée.
        _upsert_card(session, sync_payload("https://cdn.example/v1.png"))
        session.commit()
        assert session.get(Card, "scan-sync").image_hash == "ab" * 64

        # Visuel modifié : l'empreinte ne correspond plus, elle est invalidée (recalcul via l'admin).
        _upsert_card(session, sync_payload("https://cdn.example/v2.png"))
        session.commit()
        row = session.get(Card, "scan-sync")
        assert row.image_url == "https://cdn.example/v2.png"
        assert row.image_hash is None


def test_hash_backfill_worker_loops_until_done(monkeypatch):
    """Le worker enchaîne les lots jusqu'à remaining=0 puis s'arrête."""
    from app import main

    results = iter(
        [
            {"computed": 300, "failed": 0, "remaining": 100},
            {"computed": 100, "failed": 0, "remaining": 0},
        ]
    )
    calls = []
    monkeypatch.setattr(main, "_compute_hash_batch", lambda db: calls.append(1) or next(results))
    monkeypatch.setattr(main, "_HASH_WORKER_PAUSE", 0)

    main._hash_backfill_worker()

    assert len(calls) == 2


def test_hash_backfill_worker_stops_on_stagnation(monkeypatch):
    """Lot entièrement en échec (CDN injoignable) : le worker n'insiste pas."""
    from app import main

    calls = []
    monkeypatch.setattr(
        main, "_compute_hash_batch", lambda db: calls.append(1) or {"computed": 0, "failed": 300, "remaining": 300}
    )
    monkeypatch.setattr(main, "_HASH_WORKER_PAUSE", 0)

    main._hash_backfill_worker()

    assert len(calls) == 1


def test_schedule_hash_backfill_respects_autostart(monkeypatch):
    """HASH_AUTOSTART=0 (les tests) : aucun thread lancé ; activé : un thread part."""
    from app import main

    started = []
    monkeypatch.setattr(
        main.threading, "Thread", lambda **kw: started.append(kw) or type("T", (), {"start": lambda s: None})()
    )

    main.schedule_hash_backfill()
    assert started == []  # autostart désactivé par conftest

    monkeypatch.setattr(main.settings, "hash_autostart", True)
    main.schedule_hash_backfill()
    assert len(started) == 1 and started[0]["daemon"] is True


def test_dhash_refuses_an_oversized_image(monkeypatch):
    """Bombe de décompression : le seuil par défaut de Pillow ne lève qu'au double,
    trop tard pour un conteneur limité à 512 Mo."""
    from io import BytesIO

    import pytest
    from app import imagehash
    from PIL import Image

    buffer = BytesIO()
    Image.new("RGB", (200, 200), (10, 20, 30)).save(buffer, format="PNG")

    monkeypatch.setattr(imagehash, "MAX_IMAGE_PIXELS", 100)  # 200x200 dépasse
    with pytest.raises(ValueError, match="trop grande"):
        imagehash.dhash_hex(buffer.getvalue())


def test_image_hash_download_is_size_capped(monkeypatch):
    """4 téléchargements en parallèle × réponse non bornée = RAM du conteneur.
    La coupure doit intervenir pendant la lecture, pas après."""
    import httpx
    import respx
    from app import main as main_module

    monkeypatch.setattr(main_module, "HASH_MAX_BYTES", 512)
    url = "https://cdn.example/enorme.png"

    with respx.mock:
        respx.get(url).mock(return_value=httpx.Response(200, content=b"\x00" * 4096))
        with httpx.Client() as http:
            assert main_module._fetch_image_hash(http, url) is None
