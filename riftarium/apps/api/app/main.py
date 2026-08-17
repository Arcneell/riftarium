import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .config import settings
from .db import Base, SessionLocal, engine, ensure_schema, get_db
from .models import Card
from .routers import auth_routes, cards, collection, decks
from .sync import run_sync

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("riftarium")


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(engine)
    ensure_schema()
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
    return run_sync(db)
