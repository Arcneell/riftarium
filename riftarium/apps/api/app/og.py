"""Image de partage (Open Graph) d'un deck : PNG 1200×630 dessiné avec Pillow.

Discord, Bluesky et consorts ne lisent pas le JavaScript : l'aperçu d'un lien
de deck doit exister côté serveur. On dessine donc la vignette localement —
illustration de la légende récupérée sur le CDN autorisé (mêmes hôtes que le
front, cf. sanitize_image_url), typographie du site embarquée en TTF.

Aucun stockage : le rendu est mis en cache en mémoire (lru_cache), invalidé
par la date de mise à jour du deck qui fait partie de la clé.
"""

import logging
from functools import lru_cache
from io import BytesIO
from pathlib import Path

import httpx
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from .security import sanitize_image_url

log = logging.getLogger("riftarium.og")

FONTS = Path(__file__).parent / "assets" / "fonts"
DISPLAY = "Marcellus-Regular.ttf"
MONO = "IBMPlexMono-Regular.ttf"
MONO_BOLD = "IBMPlexMono-SemiBold.ttf"

WIDTH, HEIGHT = 1200, 630
PAD = 72
ART_BOX = (800, 86, 1128, 544)  # vignette de la légende, à droite
TEXT_WIDTH = ART_BOX[0] - PAD - 48

# Palette du site (apps/web/src/assets/main.css)
INK = (10, 20, 40)
PAPER = (245, 239, 225)
GOLD = (176, 138, 62)
GOLD_SOFT = (217, 189, 130)
MUTED = (176, 170, 154)

HTTP_TIMEOUT = 8
MAX_ART_BYTES = 6 * 1024 * 1024
CACHE_SIZE = 96
# Garde-fou « bombe de décompression » : un PNG de quelques Ko peut déclarer
# 30000×30000 pixels et faire exploser la RAM à l'ouverture. 1200×630 suffit ici,
# on laisse large pour un visuel de carte plein format.
MAX_ART_PIXELS = 40_000_000


@lru_cache(maxsize=16)
def _font(name: str, size: int) -> ImageFont.FreeTypeFont:
    """Police du site, avec repli sur la police intégrée de Pillow (tests, image incomplète)."""
    try:
        return ImageFont.truetype(str(FONTS / name), size)
    except OSError:
        log.warning("Police %s introuvable, repli sur la police par défaut", name)
        return ImageFont.load_default(size=size)


def _fetch_art(url: str | None) -> Image.Image | None:
    """Télécharge une illustration de carte (hôte CDN autorisé uniquement).

    Trois garde-fous, parce que cette requête sort du réseau Docker et qu'aucun
    reverse proxy en entrée ne peut la surveiller :
    - follow_redirects=False : sanitize_image_url ne valide que l'URL de départ ;
      une redirection du CDN emmènerait la requête vers n'importe quel hôte,
      y compris les services internes (api:8000, db:5432, redis:6379).
    - lecture en flux, coupée à MAX_ART_BYTES : la taille était vérifiée après
      avoir déjà tout mis en mémoire.
    - MAX_ART_PIXELS : refuse les images dont les dimensions déclarées feraient
      exploser la RAM au décodage.
    """
    safe = sanitize_image_url(url)
    if not safe:
        return None
    try:
        with httpx.Client(timeout=HTTP_TIMEOUT, follow_redirects=False) as client:
            with client.stream("GET", safe) as response:
                if response.is_redirect:
                    log.info("Illustration refusée pour l'aperçu (%s) : redirection hors allow-list", safe)
                    return None
                response.raise_for_status()
                buffer = BytesIO()
                for chunk in response.iter_bytes():
                    buffer.write(chunk)
                    if buffer.tell() > MAX_ART_BYTES:
                        log.info("Illustration ignorée pour l'aperçu (%s) : plus de %s octets", safe, MAX_ART_BYTES)
                        return None
        buffer.seek(0)
        art = Image.open(buffer)
        width, height = art.size
        if width * height > MAX_ART_PIXELS:
            log.info("Illustration ignorée pour l'aperçu (%s) : %sx%s pixels", safe, width, height)
            return None
        art.load()
        return art.convert("RGB")
    except Exception as exc:  # réseau, redirection refusée, format exotique, image tronquée…
        log.info("Illustration indisponible pour l'aperçu (%s) : %s", safe, exc)
        return None


def _cover(art: Image.Image, width: int, height: int, focus: float = 0.35) -> Image.Image:
    """Recadre en « cover » : remplit la boîte sans déformer, ancré à hauteur `focus`."""
    scale = max(width / art.width, height / art.height)
    resized = art.resize((max(1, round(art.width * scale)), max(1, round(art.height * scale))), Image.LANCZOS)
    left = (resized.width - width) // 2
    top = min(max(0, round((resized.height - height) * focus)), max(0, resized.height - height))
    return resized.crop((left, top, left + width, top + height))


def _scrim() -> Image.Image:
    """Voile sombre en dégradé horizontal : texte lisible à gauche, illustration visible à droite."""
    row = Image.new("L", (WIDTH, 1))
    row.putdata([round(243 - 118 * (x / WIDTH)) for x in range(WIDTH)])
    return row.resize((WIDTH, HEIGHT))


def _rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def _wrap(draw: ImageDraw.ImageDraw, text: str, font, max_width: int, max_lines: int) -> list[str]:
    """Découpe un texte en `max_lines` lignes au plus ; la dernière est tronquée avec une ellipse."""
    words = (text or "").split()
    lines: list[str] = []
    current = ""
    index = 0
    while index < len(words) and len(lines) < max_lines:
        candidate = f"{current} {words[index]}".strip()
        if current and draw.textlength(candidate, font=font) > max_width:
            lines.append(current)
            current = ""
            continue
        current = candidate
        index += 1
    if current and len(lines) < max_lines:
        lines.append(current)
        current = ""
    if not lines:
        return [""]
    if current or index < len(words) or draw.textlength(lines[-1], font=font) > max_width:
        last = lines[-1]
        while last and draw.textlength(f"{last}…", font=font) > max_width:
            last = last[:-1]
        lines[-1] = f"{last.rstrip()}…"
    return lines


def _pill(draw: ImageDraw.ImageDraw, x: int, y: int, label: str, font, *, ink, border, fill) -> int:
    """Dessine une pastille et renvoie l'abscisse de fin."""
    width = round(draw.textlength(label, font=font)) + 34
    draw.rounded_rectangle((x, y, x + width, y + 46), radius=23, fill=fill, outline=border, width=2)
    draw.text((x + 17, y + 23), label, font=font, fill=ink, anchor="lm")
    return x + width


@lru_cache(maxsize=CACHE_SIZE)
def deck_og_png(
    *,
    name: str,
    owner: str,
    legal: bool,
    card_count: int,
    legend: str | None,
    price: str | None,
    art_url: str | None,
    stamp: str | None = None,  # date de mise à jour : sert uniquement de clé de cache
) -> bytes:
    """Rend l'image de partage d'un deck (PNG 1200×630)."""
    art = _fetch_art(art_url)

    base = Image.new("RGB", (WIDTH, HEIGHT), INK)
    if art is not None:
        base.paste(_cover(art, WIDTH, HEIGHT).filter(ImageFilter.GaussianBlur(22)))
    base.paste(Image.new("RGB", (WIDTH, HEIGHT), INK), (0, 0), _scrim())

    layer = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    # Filet doré : le cadre des encarts du site.
    draw.rounded_rectangle((18, 18, WIDTH - 19, HEIGHT - 19), radius=26, outline=(*GOLD, 110), width=2)

    if art is not None:
        box_w, box_h = ART_BOX[2] - ART_BOX[0], ART_BOX[3] - ART_BOX[1]
        card = _cover(art, box_w, box_h, focus=0.0)
        rounded = Image.new("RGBA", (box_w, box_h), (0, 0, 0, 0))
        rounded.paste(card, (0, 0), _rounded_mask((box_w, box_h), 20))
        layer.alpha_composite(rounded, (ART_BOX[0], ART_BOX[1]))
        draw.rounded_rectangle(
            (ART_BOX[0], ART_BOX[1], ART_BOX[2] - 1, ART_BOX[3] - 1), radius=20, outline=(*GOLD_SOFT, 170), width=3
        )

    # Bloc de texte centré verticalement : sans cela un deck sans légende laisse
    # un grand vide entre le titre et les pastilles.
    title_font = _font(DISPLAY, 62)
    title_lines = _wrap(draw, name, title_font, TEXT_WIDTH, 2)
    block = 52 + 74 * len(title_lines) + 38 + (44 if legend else 0) + 34 + 46
    y = min(max(PAD + 6, (HEIGHT - block) // 2), HEIGHT - PAD - 52 - block)

    draw.text((PAD, y), "RIFTARIUM · DECK", font=_font(MONO_BOLD, 22), fill=(*GOLD_SOFT, 255))
    y += 52

    for line in title_lines:
        draw.text((PAD, y), line, font=title_font, fill=(*PAPER, 255))
        y += 74

    y += 4
    draw.text((PAD, y), f"par {owner}", font=_font(MONO, 26), fill=(*MUTED, 255))
    y += 34

    if legend:
        y += 10
        legend_font = _font(MONO, 24)
        label = _wrap(draw, f"Légende · {legend}", legend_font, TEXT_WIDTH, 1)[0]
        draw.text((PAD, y), label, font=legend_font, fill=(*GOLD_SOFT, 220))
        y += 34

    pill_font = _font(MONO_BOLD, 24)
    pill_y = y + 34
    end = _pill(
        draw,
        PAD,
        pill_y,
        "Légal" if legal else "Illégal",
        pill_font,
        ink=(*INK, 255) if legal else (*PAPER, 255),
        border=(*GOLD, 255) if legal else (*MUTED, 160),
        fill=(*GOLD_SOFT, 245) if legal else (255, 255, 255, 26),
    )
    end = _pill(
        draw,
        end + 14,
        pill_y,
        f"{card_count} cartes",
        pill_font,
        ink=(*PAPER, 255),
        border=(*GOLD, 130),
        fill=(255, 255, 255, 20),
    )
    if price:
        _pill(
            draw, end + 14, pill_y, price, pill_font, ink=(*PAPER, 255), border=(*GOLD, 130), fill=(255, 255, 255, 20)
        )

    draw.text((PAD, HEIGHT - PAD + 2), "riftarium.re", font=_font(MONO_BOLD, 24), fill=(*GOLD_SOFT, 235))

    out = BytesIO()
    Image.alpha_composite(base.convert("RGBA"), layer).convert("RGB").save(out, format="PNG", optimize=True)
    return out.getvalue()


def clear_cache() -> None:
    deck_og_png.cache_clear()
