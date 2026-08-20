"""Analytique de fréquentation agrégée et anonyme (engagement « zéro traceur »).

Le front envoie un ping à chaque changement de route ; seuls des compteurs
jour × section sont persistés (table page_hits). Aucune donnée personnelle
n'est stockée : ni IP, ni identifiant, ni user-agent, ni cookie.

Visiteurs uniques : une empreinte SHA-256(jour + IP + secret serveur) — même
esprit que le visitor_key anonyme des deck_views, salée en plus par le secret
serveur — vit UNIQUEMENT dans un set Redis à durée de vie 48 h. Si l'empreinte
est nouvelle ce jour-là, le compteur uniques de la ligne réservée
section="site" est incrémenté. Sans Redis (dev, tests), les hits sont comptés
normalement mais les uniques restent à 0 : aucune déduplication n'est possible
sans stocker l'empreinte, ce qu'on refuse de faire en base.
"""

import hashlib
from datetime import date

from fastapi import APIRouter, Depends, Request
from sqlalchemy import update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..cache import _redis
from ..config import settings
from ..db import get_db
from ..models import PageHit, utcnow
from ..schemas import HitIn
from ..security import allow_rate, client_ip

router = APIRouter(prefix="/api/metrics", tags=["metrics"])

# Allow-list fermée des écrans du site : tout le reste est agrégé dans « autre »
# (aucune valeur libre en base, même pas un chemin d'URL).
SECTIONS = frozenset(
    {"home", "cartes", "carte", "regles", "decks", "deck", "communaute", "collection", "scan", "profil", "autre"}
)
# Ligne réservée aux visiteurs uniques tous écrans confondus (hors allow-list).
SITE_SECTION = "site"

UNIQUES_TTL = 48 * 3600  # l'empreinte Redis meurt d'elle-même (jour courant + marge)


def normalize_section(value: str) -> str:
    """Rabat toute saisie sur l'allow-list : inconnue → « autre »."""
    section = (value or "").strip().lower()
    return section if section in SECTIONS else "autre"


def _bump(db: Session, day: date, section: str, *, hits: int = 0, uniques: int = 0) -> None:
    """Incrément atomique côté SQL (même motif que les compteurs de decks).

    UPDATE d'abord ; si la ligne du jour n'existe pas encore, insertion sous
    savepoint pour survivre à la course entre deux premières visites.
    """
    values = {}
    if hits:
        values["hits"] = PageHit.hits + hits
    if uniques:
        values["uniques"] = PageHit.uniques + uniques
    result = db.execute(update(PageHit).where(PageHit.day == day, PageHit.section == section).values(**values))
    if result.rowcount:
        return
    try:
        with db.begin_nested():
            db.add(PageHit(day=day, section=section, hits=hits, uniques=uniques))
    except IntegrityError:  # une requête concurrente a créé la ligne entre-temps
        db.execute(update(PageHit).where(PageHit.day == day, PageHit.section == section).values(**values))


def _visitor_fingerprint(ip: str, day: date) -> str:
    """Empreinte anonyme et non rejouable d'un jour sur l'autre (salée par le secret serveur)."""
    return hashlib.sha256(f"{day.isoformat()}:{ip}:{settings.jwt_secret}".encode()).hexdigest()


def _is_new_visitor_today(ip: str, day: date) -> bool:
    """Vrai si l'empreinte du visiteur n'a pas encore été vue aujourd'hui (set Redis, TTL 48 h)."""
    client = _redis()
    if client is None:
        return False  # sans Redis : pas de déduplication possible, uniques reste à 0
    try:
        key = f"riftarium:metrics:uniq:{day.isoformat()}"
        added = int(client.sadd(key, _visitor_fingerprint(ip, day)))
        client.expire(key, UNIQUES_TTL)
        return added == 1
    except Exception:  # Redis tombé : on ne bloque jamais le ping pour autant
        return False


@router.post("/hit", status_code=204)
def record_hit(payload: HitIn, request: Request, db: Session = Depends(get_db)):
    """Comptabilise une visite d'écran. Public, anonyme, jamais bloquant."""
    ip = client_ip(request)
    if not allow_rate(f"metrics:{ip}", settings.metrics_rate_limit):
        return  # spam : le ping est ignoré silencieusement (204 quand même, rien à révéler)
    day = utcnow().date()
    _bump(db, day, normalize_section(payload.section), hits=1)
    if _is_new_visitor_today(ip, day):
        _bump(db, day, SITE_SECTION, uniques=1)
    db.commit()
