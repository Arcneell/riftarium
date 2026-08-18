import logging
import time
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .cache import cache_clear, cache_get, cache_set
from .config import settings
from .db import Base, SessionLocal, engine, ensure_schema, get_db
from .demo import seed_community
from .models import Card
from .routers import auth_routes, cards, collection, decks
from .sync import run_sync

_last_sync_fallback = 0.0  # utilisé quand Redis est absent

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("riftarium")


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(engine)
    ensure_schema()
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
)

app.include_router(auth_routes.router)
app.include_router(cards.router)
app.include_router(collection.router)
app.include_router(decks.router)


@app.get("/api/health")
def health(db: Session = Depends(get_db)):
    return {"status": "ok", "cards": db.scalar(select(func.count(Card.id))) or 0}


@app.post("/api/admin/sync")
def admin_sync(db: Session = Depends(get_db)):
    """Resynchronise depuis Riftcodex, au plus une fois par intervalle configuré.

    L'API communautaire est gratuite : le garde-fou évite de la marteler
    (et de se faire bloquer) si l'endpoint est appelé en boucle.
    """
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

    counts = run_sync(db)
    _last_sync_fallback = now
    cache_set("sync:last", now, interval)
    cache_clear("cards:")
    cache_clear("sets:")
    return counts


_DEMO_SECRETS = {"dev-secret-change-me", "test-secret"}


@app.post("/api/admin/demo-community")
def admin_demo_community(
    reset: bool = True,
    limit: int | None = Query(default=None, ge=1, le=200),
    db: Session = Depends(get_db),
):
    """Remplit la communauté de decks de démo (local uniquement)."""
    if settings.jwt_secret not in _DEMO_SECRETS:
        raise HTTPException(status_code=403, detail="Jeux de démo désactivés hors environnement local")
    try:
        return seed_community(db, reset=reset, limit=limit)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
