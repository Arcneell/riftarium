"""Empreinte perceptuelle des visuels de cartes (dHash « dhash16-hv-art »).

Le serveur calcule l'empreinte de chaque visuel (une fois, depuis le CDN Riot)
et l'expose via GET /api/cards/hashes ; le client (scan mobile) calcule la même
empreinte sur sa photo et fait le matching localement — aucune image n'est
envoyée au serveur.

Spécification (reproduite à l'identique en JS côté front — ne pas dévier) :
- Recadrage sur la fenêtre d'illustration : x de 6 % à 94 % de la largeur,
  y de 6 % à 54 % de la hauteur (coordonnées arrondies avec ``round()``).
  Les zones de texte imprimé sont exclues : l'empreinte est indépendante de la
  langue de la carte physique (les visuels de référence n'existent qu'en EN).
- Niveaux de gris ITU-R 601-2 (Pillow ``convert("L")`` : 0.299R + 0.587G + 0.114B).
- Gradient horizontal : crop → 17×16 (LANCZOS), bit[y][x] = 1 si px[y][x] > px[y][x+1] → 256 bits.
- Gradient vertical : crop → 16×17 (LANCZOS), bit[y][x] = 1 si px[y][x] > px[y+1][x] → 256 bits.
- Empreinte = 512 bits (H puis V) = 128 caractères hex, bits ligne par ligne,
  MSB en premier dans chaque octet.
"""

from io import BytesIO

from PIL import Image

# Libellé vérifié par le client : tout changement de spec doit en changer le nom.
ALGO = "dhash16-hv-art"

# 16×16 bits par gradient : les redimensionnements portent une colonne (H) ou une ligne (V) de plus.
GRID = 16
HASH_HEX_LENGTH = 128  # 512 bits

# Fenêtre d'illustration, en fractions de la taille de l'image (voir docstring).
ART_LEFT, ART_RIGHT = 0.06, 0.94
ART_TOP, ART_BOTTOM = 0.06, 0.54


def _art_window(image: Image.Image) -> Image.Image:
    """Recadre sur la fenêtre d'art : exclut cadre et zones de texte (dépendantes de la langue)."""
    width, height = image.size
    box = (round(ART_LEFT * width), round(ART_TOP * height), round(ART_RIGHT * width), round(ART_BOTTOM * height))
    return image.crop(box)


def _pack_bits_hex(bits: list[int]) -> str:
    """Bits → hex, 8 par octet, MSB en premier (même ordre que l'implémentation JS)."""
    packed = bytearray()
    for offset in range(0, len(bits), 8):
        byte = 0
        for bit in bits[offset : offset + 8]:
            byte = (byte << 1) | bit
        packed.append(byte)
    return packed.hex()


def dhash_hex(image_bytes: bytes) -> str:
    """dHash 512 bits (gradients horizontal puis vertical) de la fenêtre d'art d'une image encodée."""
    with Image.open(BytesIO(image_bytes)) as image:
        gray = _art_window(image).convert("L")
        horizontal = list(gray.resize((GRID + 1, GRID), Image.Resampling.LANCZOS).getdata())
        vertical = list(gray.resize((GRID, GRID + 1), Image.Resampling.LANCZOS).getdata())

    bits: list[int] = []
    for y in range(GRID):  # gradient horizontal : lignes de 17 pixels
        for x in range(GRID):
            bits.append(1 if horizontal[y * (GRID + 1) + x] > horizontal[y * (GRID + 1) + x + 1] else 0)
    for y in range(GRID):  # gradient vertical : colonnes de 17 pixels (lignes de 16)
        for x in range(GRID):
            bits.append(1 if vertical[y * GRID + x] > vertical[(y + 1) * GRID + x] else 0)
    return _pack_bits_hex(bits)


def hamming_hex(a: str, b: str) -> int:
    """Distance de Hamming entre deux empreintes hex de même longueur (bits différents)."""
    if len(a) != len(b):
        raise ValueError("Empreintes de longueurs différentes")
    return (int(a, 16) ^ int(b, 16)).bit_count()
