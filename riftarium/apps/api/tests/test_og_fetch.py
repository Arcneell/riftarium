"""Garde-fous du téléchargement d'illustration pour l'aperçu Open Graph.

Cette requête SORT du réseau Docker : aucun reverse proxy en entrée (BunkerWeb)
ne peut la filtrer, les contrôles doivent donc vivre ici. Pas de fixture
`no_network` dans ce fichier : on teste justement le vrai `_fetch_art`.
"""

from io import BytesIO

import httpx
import respx
from app import og
from PIL import Image

ART_URL = "https://cdn.example/art.png"  # hôte autorisé hors prod (DEV_IMAGE_HOSTS)


def png_bytes(width=400, height=560) -> bytes:
    buffer = BytesIO()
    Image.new("RGB", (width, height), (60, 40, 30)).save(buffer, format="PNG")
    return buffer.getvalue()


@respx.mock
def test_fetch_art_reads_an_authorized_host():
    respx.get(ART_URL).mock(return_value=httpx.Response(200, content=png_bytes()))
    art = og._fetch_art(ART_URL)
    assert art is not None
    assert art.mode == "RGB"
    assert art.size == (400, 560)


def test_fetch_art_refuses_a_host_outside_the_allowlist():
    """sanitize_image_url filtre en amont : aucune requête réseau n'est même émise."""
    assert og._fetch_art("https://evil.example/art.png") is None
    assert og._fetch_art("http://cdn.example/art.png") is None  # HTTPS obligatoire
    assert og._fetch_art(None) is None


@respx.mock
def test_fetch_art_does_not_follow_redirects():
    """Une redirection emmènerait la requête vers un hôte jamais validé, y compris
    les services internes (api:8000, db:5432, redis:6379) — c'est un SSRF."""
    interne = respx.get("http://api:8000/api/health").mock(return_value=httpx.Response(200, content=png_bytes()))
    respx.get(ART_URL).mock(return_value=httpx.Response(302, headers={"Location": "http://api:8000/api/health"}))

    assert og._fetch_art(ART_URL) is None
    assert not interne.called  # le service interne n'a jamais été contacté


@respx.mock
def test_fetch_art_stops_reading_past_the_size_cap(monkeypatch):
    """La taille était vérifiée APRÈS avoir tout mis en mémoire."""
    monkeypatch.setattr(og, "MAX_ART_BYTES", 512)
    respx.get(ART_URL).mock(return_value=httpx.Response(200, content=b"\x00" * 4096))
    assert og._fetch_art(ART_URL) is None


@respx.mock
def test_fetch_art_refuses_a_decompression_bomb(monkeypatch):
    """Un fichier de quelques Ko peut déclarer des dimensions énormes : le décodage
    saturerait la RAM du conteneur (mem_limit 512 Mo)."""
    monkeypatch.setattr(og, "MAX_ART_PIXELS", 100)  # 400x560 dépasse largement
    respx.get(ART_URL).mock(return_value=httpx.Response(200, content=png_bytes()))
    assert og._fetch_art(ART_URL) is None


@respx.mock
def test_fetch_art_tolerates_network_and_http_errors():
    """L'aperçu se dessine sans illustration plutôt que de renvoyer une erreur."""
    respx.get(ART_URL).mock(return_value=httpx.Response(503))
    assert og._fetch_art(ART_URL) is None

    respx.get(ART_URL).mock(side_effect=httpx.ConnectError("injoignable"))
    assert og._fetch_art(ART_URL) is None

    respx.get(ART_URL).mock(return_value=httpx.Response(200, content=b"pas une image"))
    assert og._fetch_art(ART_URL) is None
