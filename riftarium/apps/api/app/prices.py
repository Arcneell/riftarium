"""Prix des cartes : marché TCGplayer via TCGCSV, conversion en euros via la BCE.

Sources gratuites et sans clé :
- https://tcgcsv.com/tcgplayer/89/groups puis /{groupId}/prices → marketPrice
  par produit TCGplayer (catégorie 89 = Riftbound), mis à jour vers 20:00 UTC ;
- https://api.frankfurter.dev/v1/latest?base=USD&symbols=EUR → taux BCE du jour.

Le mapping carte ↔ produit passe par cards.tcgplayer_id (exposé par Riftcodex,
capté à la sync et backfillé ici pour les cartes déjà en base).

Aucun cron : sur le motif du remplissage d'empreintes (app/main.py), un thread
de veille unique dort une heure puis relance un rafraîchissement complet si le
dernier date de plus de PRICE_MAX_AGE_HOURS. Chaque étape est tolérante aux
pannes : on logge, on abandonne proprement, le cycle suivant retentera.
"""

import logging
import threading
import time
from datetime import UTC, datetime, timedelta

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from .cache import cache_clear
from .config import settings
from .db import SessionLocal
from .models import AppState, Card, PriceHistory
from .sync import HEADERS as SYNC_HEADERS

log = logging.getLogger("riftarium.prices")

TCGPLAYER_CATEGORY = 89  # Riftbound chez TCGplayer
HTTP_TIMEOUT = 15
PRICE_MAX_AGE_HOURS = 20  # TCGCSV publie une fois par jour (~20:00 UTC)
_WATCH_INTERVAL = 3600.0  # la veille se réveille toutes les heures

# Clés app_state. updated_at (horodatage) sert au critère de fraîcheur interne ;
# updated_day (date) est la valeur publique exposée par /api/prices/meta.
RATE_KEY = "prices:rate"
RATE_DATE_KEY = "prices:rate_date"
UPDATED_DAY_KEY = "prices:updated_day"
UPDATED_AT_KEY = "prices:updated_at"

CURRENCY_NOTE = "Prix du marché US (TCGplayer), convertis en euros au taux BCE — estimation indicative."


class PriceRefreshBusy(RuntimeError):
    """Un rafraîchissement des prix est déjà en cours."""


# --- app_state : petit stockage clé/valeur (le commit revient à l'appelant) ---


def state_get(db: Session, key: str) -> str | None:
    row = db.get(AppState, key)
    return row.value if row else None


def state_set(db: Session, key: str, value: str) -> None:
    row = db.get(AppState, key)
    if row is None:
        db.add(AppState(key=key, value=str(value)))
    else:
        row.value = str(value)


def current_rate(db: Session) -> float | None:
    """Taux USD→EUR stocké (BCE). None tant qu'aucun refresh n'a abouti."""
    raw = state_get(db, RATE_KEY)
    try:
        return float(raw) if raw else None
    except ValueError:  # valeur corrompue : mieux vaut « pas de prix » qu'un prix faux
        return None


def to_eur(price_usd: float | None, rate: float | None) -> float | None:
    """Prix en euros arrondi au centime, ou None si prix ou taux inconnu."""
    if price_usd is None or rate is None:
        return None
    return round(price_usd * rate, 2)


# --- Étapes du rafraîchissement -------------------------------------------------


def _backfill_tcgplayer_ids(db: Session, http: httpx.Client) -> int:
    """Récupère depuis Riftcodex les tcgplayer_id des cartes qui n'en ont pas.

    Nécessaire pour les cartes synchronisées avant l'ajout de la colonne : la
    sync normale (app/sync.py) capte désormais l'identifiant au fil de l'eau.
    """
    missing = set(db.scalars(select(Card.id).where(Card.tcgplayer_id.is_(None))).all())
    if not missing:
        return 0
    base = settings.riftcodex_base_url.rstrip("/")
    wanted = sorted({s.strip().lower() for s in settings.sync_sets.split(",") if s.strip()})
    filled = 0
    for set_id in wanted:
        page = 1
        while True:
            response = http.get(f"{base}/cards", params={"set_id": set_id, "page": page, "size": 100})
            if response.status_code != 200:
                log.warning("prix : backfill %s page %s -> HTTP %s", set_id, page, response.status_code)
                break
            data = response.json()
            for item in data.get("items", []):
                tcgplayer_id = item.get("tcgplayer_id")
                if tcgplayer_id and item.get("id") in missing:
                    db.get(Card, item["id"]).tcgplayer_id = str(tcgplayer_id)
                    filled += 1
            if page >= data.get("pages", 1):
                break
            page += 1
            time.sleep(settings.riftcodex_page_delay)
    db.commit()
    return filled


def _download_market_prices(http: httpx.Client) -> dict[str, dict[str, float]]:
    """Télécharge les prix TCGplayer de tous les groupes : productId → {sous-type → marketPrice}."""
    base = settings.tcgcsv_base_url.rstrip("/")
    groups = http.get(f"{base}/tcgplayer/{TCGPLAYER_CATEGORY}/groups").raise_for_status().json().get("results", [])
    prices: dict[str, dict[str, float]] = {}
    for group in groups:
        group_id = group.get("groupId")
        try:
            rows = (
                http.get(f"{base}/tcgplayer/{TCGPLAYER_CATEGORY}/{group_id}/prices")
                .raise_for_status()
                .json()
                .get("results", [])
            )
        except Exception as exc:  # un groupe en panne n'empêche pas les autres
            log.warning("prix : groupe TCGplayer %s indisponible (%s) — ignoré", group_id, exc)
            continue
        for row in rows:
            market = row.get("marketPrice")
            if market is None or row.get("productId") is None:
                continue
            prices.setdefault(str(row["productId"]), {})[row.get("subTypeName") or "Normal"] = float(market)
    if not prices:
        raise RuntimeError("aucun prix téléchargé depuis TCGCSV")
    return prices


def _apply_market_prices(db: Session, prices: dict[str, dict[str, float]]) -> int:
    """Met à jour cards.price_usd (Normal en priorité, Foil en repli) et price_foil_usd."""
    priced = 0
    for card in db.scalars(select(Card).where(Card.tcgplayer_id.is_not(None))).all():
        entry = prices.get(card.tcgplayer_id)
        if not entry:  # produit absent du dump du jour : on garde le dernier prix connu
            continue
        normal = entry.get("Normal")
        foil = entry.get("Foil")
        card.price_usd = normal if normal is not None else foil
        card.price_foil_usd = foil
        if card.price_usd is not None:
            priced += 1
    db.commit()
    return priced


def _refresh_rate(db: Session, http: httpx.Client) -> float:
    """Taux USD→EUR du jour (BCE via frankfurter), stocké dans app_state."""
    base = settings.frankfurter_base_url.rstrip("/")
    payload = http.get(f"{base}/v1/latest", params={"base": "USD", "symbols": "EUR"}).raise_for_status().json()
    rate = float(payload["rates"]["EUR"])
    state_set(db, RATE_KEY, str(rate))
    state_set(db, RATE_DATE_KEY, str(payload.get("date") or ""))
    db.commit()
    return rate


def _record_history(db: Session, day) -> int:
    """Une ligne price_history par carte à prix connu — upsert idempotent sur (day, card_id)."""
    rows = db.execute(select(Card.id, Card.price_usd).where(Card.price_usd.is_not(None))).all()
    existing = {entry.card_id: entry for entry in db.scalars(select(PriceHistory).where(PriceHistory.day == day))}
    for card_id, price in rows:
        entry = existing.get(card_id)
        if entry is None:
            db.add(PriceHistory(day=day, card_id=card_id, market_usd=price))
        else:
            entry.market_usd = price
    db.commit()
    return len(rows)


def refresh_prices(db: Session) -> dict:
    """Rafraîchissement complet : backfill des ids, prix, taux, historique, horodatage.

    Tolérant aux pannes : le backfill ou le taux en échec n'empêchent pas le
    reste ; TCGCSV totalement indisponible → abandon propre sans horodatage,
    donc nouvelle tentative au prochain cycle de veille.
    """
    now = datetime.now(UTC)
    summary = {"status": "ok", "backfilled_ids": 0, "priced_cards": 0, "history_rows": 0}
    with httpx.Client(timeout=HTTP_TIMEOUT, headers=SYNC_HEADERS) as http:
        try:
            summary["backfilled_ids"] = _backfill_tcgplayer_ids(db, http)
        except Exception:  # sans mapping frais, les cartes déjà mappées restent rafraîchissables
            log.exception("prix : backfill des tcgplayer_id impossible — on continue avec l'existant")

        try:
            prices = _download_market_prices(http)
        except Exception:
            log.exception("prix : téléchargement TCGCSV impossible — nouvelle tentative au prochain cycle")
            summary["status"] = "aborted"
            return summary
        summary["priced_cards"] = _apply_market_prices(db, prices)

        try:
            _refresh_rate(db, http)
        except Exception:  # l'ancien taux (s'il existe) reste valable pour l'affichage
            log.warning("prix : taux USD→EUR indisponible — ancien taux conservé", exc_info=True)

    summary["history_rows"] = _record_history(db, now.date())
    state_set(db, UPDATED_DAY_KEY, now.date().isoformat())
    state_set(db, UPDATED_AT_KEY, now.isoformat())
    db.commit()
    # Les réponses cartes (prix inclus) et la météo des prix ne sont plus à jour.
    cache_clear("cards:")
    cache_clear("prices:")
    log.info("prix : %s cartes pricées (taux et historique à jour)", summary["priced_cards"])
    return summary


# --- Orchestration « sans cron », sur le motif du remplissage d'empreintes -------

_price_refresh_lock = threading.Lock()
_watch_started = threading.Event()


def run_price_refresh(db: Session) -> dict:
    """Rafraîchissement synchrone (endpoint admin) — refuse si un autre est en cours."""
    if not _price_refresh_lock.acquire(blocking=False):
        raise PriceRefreshBusy("Rafraîchissement des prix déjà en cours")
    try:
        return refresh_prices(db)
    finally:
        _price_refresh_lock.release()


def _price_refresh_worker() -> None:
    if not _price_refresh_lock.acquire(blocking=False):
        return  # un rafraîchissement est déjà en cours
    try:
        with SessionLocal() as db:
            refresh_prices(db)
    except Exception:  # jamais bloquant pour l'application
        log.exception("rafraîchissement des prix interrompu par une erreur inattendue")
    finally:
        _price_refresh_lock.release()


def schedule_price_refresh() -> None:
    """Lance (au plus un) rafraîchissement des prix en arrière-plan."""
    threading.Thread(target=_price_refresh_worker, name="price-refresh", daemon=True).start()


def _refresh_due() -> bool:
    """Vrai si aucun refresh abouti, ou si le dernier date de plus de PRICE_MAX_AGE_HOURS."""
    with SessionLocal() as db:
        raw = state_get(db, UPDATED_AT_KEY)
    if not raw:
        return True
    try:
        last = datetime.fromisoformat(raw)
    except ValueError:
        return True
    return datetime.now(UTC) - last > timedelta(hours=PRICE_MAX_AGE_HOURS)


def _price_watch_loop() -> None:
    """Boucle de veille : vérifie chaque heure, déclenche quand les prix sont périmés."""
    while True:
        try:
            if _refresh_due():
                schedule_price_refresh()
        except Exception:  # la veille survit à tout (base indisponible, etc.)
            log.exception("veille des prix : erreur inattendue")
        time.sleep(_WATCH_INTERVAL)


def start_price_watch() -> None:
    """Démarre (une seule fois) le thread de veille des prix — appelé au lifespan."""
    if not settings.prices_autorefresh:
        return
    if _watch_started.is_set():
        return  # déjà démarré (redémarrage du lifespan dans le même processus)
    _watch_started.set()
    threading.Thread(target=_price_watch_loop, name="price-watch", daemon=True).start()
