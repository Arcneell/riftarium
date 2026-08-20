import logging
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .cache import cache_clear, cache_get, cache_set
from .config import settings, validate_production_settings
from .db import SessionLocal, get_db, run_migrations
from .demo import seed_community
from .imagehash import dhash_hex
from .models import Card, Deck
from .routers import auth_routes, cards, collection, decks
from .schemas import ModerationIn
from .security import require_admin_token, sanitize_image_url
from .sync import HEADERS as SYNC_HEADERS
from .sync import run_sync

_last_sync_fallback = 0.0  # utilisé quand Redis est absent

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("riftarium")


@asynccontextmanager
async def lifespan(app: FastAPI):
    validate_production_settings()
    run_migrations()
    # Une instance précédente a pu mettre en cache un état partiel (sync en cours)
    # ou obsolète (schéma/données modifiés) : on repart d'un cache propre.
    cache_clear("cards:")
    cache_clear("sets:")
    if settings.auto_sync:
        with SessionLocal() as db:
            count = db.scalar(select(func.count(Card.id))) or 0
            if count == 0:
                log.info("base vide : synchronisation initiale depuis Riftcodex…")
                try:
                    run_sync(db)
                except Exception:  # le service démarre même si la source est indisponible
                    log.exception("synchronisation initiale échouée — réessayez via POST /api/admin/sync")
    # Empreintes du scan : les manquantes se calculent toutes seules en arrière-plan.
    schedule_hash_backfill()
    yield


app = FastAPI(
    title="Riftarium API",
    version="0.1.0",
    description=(
        "API du projet Riftarium — compagnon communautaire Riftbound. "
        "Projet fan-made à but non lucratif, non affilié à Riot Games. "
        "Données de cartes : API communautaire Riftcodex ; visuels servis par le CDN officiel Riot."
    ),
    lifespan=lifespan,
    docs_url="/docs" if settings.expose_docs else None,
    redoc_url="/redoc" if settings.expose_docs else None,
    openapi_url="/openapi.json" if settings.expose_docs else None,
)

app.include_router(auth_routes.router)
app.include_router(cards.router)
app.include_router(collection.router)
app.include_router(decks.router)


@app.get("/api/health")
def health():
    return {"status": "ok"}


@app.post("/api/admin/sync")
def admin_sync(
    db: Session = Depends(get_db),
    x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
):
    """Resynchronise depuis Riftcodex, au plus une fois par intervalle configuré.

    Protégé par ADMIN_TOKEN. L'API communautaire est gratuite : le garde-fou
    évite de la marteler (et de se faire bloquer) si l'endpoint est appelé en boucle.
    """
    require_admin_token(x_admin_token)
    global _last_sync_fallback
    now = time.time()
    interval = settings.sync_min_interval_minutes * 60
    last = cache_get("sync:last") or _last_sync_fallback
    if last and now - float(last) < interval:
        wait = int(interval - (now - float(last)))
        raise HTTPException(
            status_code=429,
            detail=f"Sync déjà effectuée récemment — réessayez dans {wait}s",
        )

    # Le garde-fou est posé AVANT la sync : deux requêtes simultanées ne lancent pas deux syncs.
    _last_sync_fallback = now
    cache_set("sync:last", now, interval)
    try:
        counts = run_sync(db)
    finally:
        # Même en cas d'échec partiel, on ne laisse pas un cache incohérent avec la base.
        cache_clear("cards:")
        cache_clear("sets:")
    # Les cartes nouvelles ou au visuel changé n'ont plus d'empreinte : recalcul auto.
    schedule_hash_backfill()
    return counts


# Bornes du recalcul d'empreintes : rester sous les timeouts HTTP (rappeler
# l'endpoint jusqu'à remaining=0) et ménager le CDN (4 téléchargements en parallèle max).
HASH_BATCH_SIZE = 300
HASH_DOWNLOAD_WORKERS = 4
HASH_DOWNLOAD_TIMEOUT = 10


def _fetch_image_hash(http: httpx.Client, url: str) -> str | None:
    """Télécharge un visuel et calcule son dHash ; toute erreur est loggée et tolérée."""
    try:
        response = http.get(url)
        response.raise_for_status()
        return dhash_hex(response.content)
    except Exception as exc:  # erreur par carte (réseau, HTTP, image invalide) : on passe à la suivante
        log.warning("empreinte impossible pour %s : %s", url, exc)
        return None


def _missing_hash_clause():
    """Cartes candidates au calcul : pas d'empreinte, mais un visuel connu."""
    return (Card.image_hash.is_(None), Card.image_url.is_not(None))


def _compute_hash_batch(db: Session) -> dict:
    """Calcule un lot d'empreintes manquantes (HASH_BATCH_SIZE max) et le bilan."""
    batch = db.scalars(select(Card).where(*_missing_hash_clause()).order_by(Card.id).limit(HASH_BATCH_SIZE)).all()

    computed = failed = 0
    with (
        httpx.Client(timeout=HASH_DOWNLOAD_TIMEOUT, headers=SYNC_HEADERS) as http,
        ThreadPoolExecutor(max_workers=HASH_DOWNLOAD_WORKERS) as pool,
    ):
        futures = {}
        for card in batch:
            url = sanitize_image_url(card.image_url)
            if url is None:  # hôte hors allow-list : on ne télécharge jamais
                log.warning("empreinte ignorée pour %s : URL d'image non autorisée", card.id)
                failed += 1
                continue
            futures[card.id] = (card, pool.submit(_fetch_image_hash, http, url))
        for card, future in futures.values():
            digest = future.result()
            if digest is None:
                failed += 1
            else:
                card.image_hash = digest
                computed += 1
    db.commit()
    if computed:
        cache_clear("cards:hashes")  # l'index public doit refléter les nouvelles empreintes

    remaining = db.scalar(select(func.count()).select_from(select(Card.id).where(*_missing_hash_clause()).subquery()))
    return {"computed": computed, "failed": failed, "remaining": remaining or 0}


# Remplissage automatique en tâche de fond : au démarrage et après chaque sync,
# les empreintes manquantes sont calculées lot par lot sans intervention.
_hash_worker_lock = threading.Lock()
_HASH_WORKER_PAUSE = 2.0  # souffle entre deux lots (ménage le CDN et la base)


def _hash_backfill_worker() -> None:
    if not _hash_worker_lock.acquire(blocking=False):
        return  # un remplissage est déjà en cours
    try:
        while True:
            with SessionLocal() as db:
                result = _compute_hash_batch(db)
            if result["remaining"] == 0:
                if result["computed"]:
                    log.info("empreintes de scan : remplissage terminé")
                return
            if result["computed"] == 0:
                # Lot entièrement en échec (réseau/CDN) : on n'insiste pas, le
                # prochain démarrage ou la prochaine sync retentera.
                log.warning("empreintes de scan : %s cartes en attente, calcul interrompu", result["remaining"])
                return
            log.info("empreintes de scan : %s calculées, %s restantes", result["computed"], result["remaining"])
            time.sleep(_HASH_WORKER_PAUSE)
    except Exception:  # jamais bloquant pour l'application
        log.exception("remplissage des empreintes interrompu par une erreur inattendue")
    finally:
        _hash_worker_lock.release()


def schedule_hash_backfill() -> None:
    """Lance (au plus un) remplissage d'empreintes en arrière-plan."""
    if not settings.hash_autostart:
        return
    threading.Thread(target=_hash_backfill_worker, name="hash-backfill", daemon=True).start()


@app.post("/api/admin/cards/hashes")
def admin_compute_card_hashes(
    db: Session = Depends(get_db),
    x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
):
    """Calcule un lot d'empreintes manquantes (secours manuel du remplissage auto)."""
    require_admin_token(x_admin_token)
    return _compute_hash_batch(db)


_DEMO_SECRETS = {"dev-secret-change-me", "test-secret", "test-secret-not-for-production-use!"}


@app.post("/api/admin/demo-community")
def admin_demo_community(
    reset: bool = True,
    limit: int | None = Query(default=None, ge=1, le=200),
    db: Session = Depends(get_db),
    x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
):
    """Remplit la communauté de decks de démo (local uniquement, jeton admin requis)."""
    require_admin_token(x_admin_token)
    if settings.jwt_secret not in _DEMO_SECRETS:
        raise HTTPException(status_code=403, detail="Jeux de démo désactivés hors environnement local")
    try:
        return seed_community(db, reset=reset, limit=limit)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.post("/api/admin/decks/{deck_id}/moderation")
def admin_moderate_deck(
    deck_id: int,
    payload: ModerationIn,
    db: Session = Depends(get_db),
    x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
):
    """Décision de modération sur un deck (débloque les decks « pending »)."""
    require_admin_token(x_admin_token)
    deck = db.get(Deck, deck_id)
    if deck is None:
        raise HTTPException(status_code=404, detail="Deck introuvable")
    deck.moderation_status = "published" if payload.status == "approved" else "rejected"
    db.commit()
    return {"deck_id": deck.id, "moderation_status": deck.moderation_status}
