"""Aperçu social d'un deck : image Open Graph et page de méta pour les robots.

Le site est une application monopage : Discord, Bluesky, Slack ou Twitter ne
lisent pas le JavaScript et ne verraient donc que les méta génériques de
index.html. nginx redirige ces robots (et eux seuls) de /decks/{id} vers
/api/decks/{id}/preview, qui rend un document HTML minimal pointant vers
/api/decks/{id}/og.png. Les humains continuent de recevoir l'application.
"""

import html

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..models import Card, Deck
from ..og import deck_og_png
from ..prices import current_rate, to_eur
from ..security import sanitize_image_url

router = APIRouter(prefix="/api", tags=["share"])

OG_CACHE = "public, max-age=3600"
PREVIEW_CACHE = "public, max-age=600"
SITE_NAME = "Riftarium"
DEFAULT_TITLE = "Riftarium — Cartes, decks et règles Riftbound"
DEFAULT_DESCRIPTION = (
    "Bêta fermée. Cartothèque, deck builder, règles officielles et collection pour Riftbound. "
    "Site fan-made gratuit, en français, non affilié à Riot Games."
)


def _public_deck(db: Session, deck_id: int) -> Deck | None:
    """Un aperçu n'existe que pour un deck public et publié — jamais pour un brouillon."""
    deck = db.get(Deck, deck_id)
    if deck is None or not (deck.is_public and deck.moderation_status == "published"):
        return None
    return deck


def _legend(deck: Deck) -> Card | None:
    return next((dc.card for dc in deck.cards if dc.card.type == "Legend"), None)


def _art_url(deck: Deck) -> str | None:
    """Illustration de l'aperçu : la légende, sinon la première carte du deck."""
    legend = _legend(deck)
    card = legend or next((dc.card for dc in deck.cards), None)
    url = sanitize_image_url(card.image_url if card else None)
    if not url:
        return None
    return url if "w=" in url else f"{url}{'&' if '?' in url else '?'}auto=format&fit=max&w=720"


def _price(deck: Deck, db: Session) -> str | None:
    rate = current_rate(db)
    prices = [dc.qty * price for dc in deck.cards if (price := to_eur(dc.card.price_usd, rate)) is not None]
    if not prices:
        return None
    return f"{round(sum(prices), 2):.2f} €".replace(".", ",")


def _summary(deck: Deck, card_count: int, price: str | None) -> str:
    described = (deck.description or "").strip().replace("\n", " ")
    if described:
        return described[:200]
    parts = [f"Deck {'légal' if deck.format != 'free' else 'illégal'} de {deck.owner.handle}", f"{card_count} cartes"]
    legend = _legend(deck)
    if legend:
        parts.insert(1, f"légende {legend.name}")
    if price:
        parts.append(f"valeur estimée {price}")
    return " · ".join(parts) + "."


def _document(*, title: str, description: str, image: str, url: str, redirect: str) -> str:
    """Document minimal : uniquement des méta, plus une redirection pour un humain égaré."""
    esc = {
        key: html.escape(value, quote=True)
        for key, value in {
            "title": title,
            "description": description,
            "image": image,
            "url": url,
            "redirect": redirect,
        }.items()
    }
    return f"""<!doctype html>
<html lang="fr">
  <head>
    <meta charset="utf-8" />
    <title>{esc["title"]}</title>
    <meta name="description" content="{esc["description"]}" />
    <meta name="robots" content="noindex, nofollow" />
    <link rel="canonical" href="{esc["url"]}" />
    <meta property="og:type" content="article" />
    <meta property="og:locale" content="fr_FR" />
    <meta property="og:site_name" content="{SITE_NAME}" />
    <meta property="og:title" content="{esc["title"]}" />
    <meta property="og:description" content="{esc["description"]}" />
    <meta property="og:url" content="{esc["url"]}" />
    <meta property="og:image" content="{esc["image"]}" />
    <meta property="og:image:width" content="1200" />
    <meta property="og:image:height" content="630" />
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="{esc["title"]}" />
    <meta name="twitter:description" content="{esc["description"]}" />
    <meta name="twitter:image" content="{esc["image"]}" />
    <meta http-equiv="refresh" content="0; url={esc["redirect"]}" />
  </head>
  <body>
    <p><a href="{esc["redirect"]}">{esc["title"]}</a></p>
  </body>
</html>
"""


@router.get("/decks/{deck_id}/og.png")
def deck_og_image(deck_id: int, db: Session = Depends(get_db)):
    """Image de partage 1200×630 d'un deck public."""
    deck = _public_deck(db, deck_id)
    if deck is None:
        raise HTTPException(status_code=404, detail="Deck introuvable")
    legend = _legend(deck)
    png = deck_og_png(
        name=deck.name,
        owner=deck.owner.handle,
        legal=deck.format != "free",
        card_count=sum(dc.qty for dc in deck.cards),
        legend=legend.name if legend else None,
        price=_price(deck, db),
        art_url=_art_url(deck),
        stamp=deck.updated_at.isoformat() if deck.updated_at else None,
    )
    return Response(content=png, media_type="image/png", headers={"Cache-Control": OG_CACHE})


@router.get("/decks/{deck_id}/preview")
def deck_preview(deck_id: int, db: Session = Depends(get_db)):
    """Méta Open Graph d'un deck, servies aux robots d'aperçu de lien (cf. nginx.conf)."""
    base = settings.base_url
    deck = _public_deck(db, deck_id)
    redirect = f"{base}/decks/{deck_id}"
    if deck is None:
        # Deck privé, en modération ou inexistant : aperçu générique, aucune fuite d'information.
        body = _document(
            title=DEFAULT_TITLE,
            description=DEFAULT_DESCRIPTION,
            image=f"{base}/icon-512.png",
            url=f"{base}/",
            redirect=redirect,
        )
    else:
        card_count = sum(dc.qty for dc in deck.cards)
        body = _document(
            title=f"{deck.name} — Deck Riftbound par {deck.owner.handle} · {SITE_NAME}",
            description=_summary(deck, card_count, _price(deck, db)),
            image=f"{base}/api/decks/{deck_id}/og.png",
            url=redirect,
            redirect=redirect,
        )
    return Response(content=body, media_type="text/html; charset=utf-8", headers={"Cache-Control": PREVIEW_CACHE})
