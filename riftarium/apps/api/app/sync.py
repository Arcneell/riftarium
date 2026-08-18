"""Synchronisation depuis l'API communautaire Riftcodex (https://api.riftcodex.com).

Récupère les sets puis toutes les cartes, et les upserte en base locale.
Les visuels restent servis par le CDN officiel de Riot — rien n'est copié.
"""

import logging
import time

import httpx
from sqlalchemy.orm import Session

from .config import settings
from .models import Card, CardSet
from .security import sanitize_image_url

log = logging.getLogger("riftarium.sync")

# S'identifier auprès de l'API communautaire et espacer les requêtes :
# Riftcodex est gratuite, on la ménage.
HEADERS = {"User-Agent": "Riftarium/0.1 (+https://github.com/Arcneell/riftarium)"}


def _upsert_set(db: Session, payload: dict) -> None:
    row = db.get(CardSet, payload["set_id"]) or CardSet(set_id=payload["set_id"])
    row.name = payload["name"]
    row.card_count = payload.get("card_count") or 0
    row.published_on = payload.get("published_on")
    db.merge(row)


def _upsert_card(db: Session, payload: dict) -> None:
    attributes = payload.get("attributes") or {}
    classification = payload.get("classification") or {}
    text = payload.get("text") or {}
    media = payload.get("media") or {}
    card_set = payload.get("set") or {}
    metadata = payload.get("metadata") or {}

    row = db.get(Card, payload["id"]) or Card(id=payload["id"])
    row.riftbound_id = payload["riftbound_id"]
    row.name = payload["name"]
    row.collector_number = payload.get("collector_number")
    row.set_id = (card_set.get("set_id") or "").upper()
    row.type = classification.get("type") or "Unknown"
    row.supertype = classification.get("supertype")
    row.rarity = classification.get("rarity")
    row.domains = classification.get("domain") or []
    row.energy = attributes.get("energy")
    row.might = attributes.get("might")
    row.power = attributes.get("power")
    row.text_plain = text.get("plain")
    row.text_flavour = text.get("flavour")
    row.image_url = sanitize_image_url(media.get("image_url"))
    row.artist = media.get("artist")
    row.orientation = payload.get("orientation")
    row.tags = payload.get("tags") or []
    row.alternate_art = bool(metadata.get("alternate_art"))
    row.signature = bool(metadata.get("signature"))
    row.overnumbered = bool(metadata.get("overnumbered"))
    row.updated_on = metadata.get("updated_on")
    db.merge(row)


def run_sync(db: Session) -> dict:
    base = settings.riftcodex_base_url.rstrip("/")
    wanted = {s.strip().upper() for s in settings.sync_sets.split(",") if s.strip()}
    counts = {"sets": 0, "cards": 0}

    with httpx.Client(timeout=30, headers=HEADERS) as client:
        sets_payload = client.get(f"{base}/sets", params={"size": 50}).raise_for_status().json()
        for item in sets_payload.get("items", []):
            if item["set_id"].upper() in wanted:
                _upsert_set(db, item)
                counts["sets"] += 1
        db.commit()

        for set_id in sorted(wanted):
            page = 1
            while True:
                response = client.get(
                    f"{base}/cards",
                    params={
                        "set_id": set_id.lower(),
                        "page": page,
                        "size": 100,
                        "sort": "collector_number",
                    },
                )
                if response.status_code != 200:
                    log.warning("sync %s page %s -> HTTP %s", set_id, page, response.status_code)
                    break
                data = response.json()
                for item in data.get("items", []):
                    _upsert_card(db, item)
                    counts["cards"] += 1
                db.commit()
                if page >= data.get("pages", 1):
                    break
                page += 1
                time.sleep(settings.riftcodex_page_delay)

    log.info("sync terminée : %s sets, %s cartes", counts["sets"], counts["cards"])
    return counts
