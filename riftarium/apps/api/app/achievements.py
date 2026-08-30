"""Hauts faits : catalogue, métriques agrégées et enregistrement des déblocages.

Le catalogue vit ici (aucune donnée d'affichage en base) ; la table
`achievements` ne retient que la clé, la date de déblocage et la valeur atteinte.
Toutes les métriques sont calculées en SQL agrégé : jamais de parcours ligne à
ligne des matchs ou de la collection. Contrat commun avec le mobile et le web :
docs/profils-et-hauts-faits.md.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, aliased

from .models import Achievement, Card, CollectionItem, Deck, Follow, Match, MatchPlayer, User, utcnow
from .validation import validate_deck


@dataclass(frozen=True)
class Definition:
    """Un haut fait du catalogue. `metric` désigne la clé calculée par `compute_metrics`."""

    key: str
    family: str
    title: str
    description: str
    icon: str  # nom d'icône Material, partagé par le mobile et le web
    tier: str  # bronze | silver | gold | prism
    threshold: int
    metric: str


# Ordre du catalogue = ordre d'affichage (par famille, puis par palier).
CATALOGUE: tuple[Definition, ...] = (
    Definition(
        "first_blood",
        "duels",
        "Premier sang",
        "Remporter un premier match suivi.",
        "military_tech",
        "bronze",
        1,
        "wins",
    ),
    Definition("veteran_10", "duels", "Habitué", "Jouer 10 matchs suivis.", "shield", "bronze", 10, "played"),
    Definition("veteran_50", "duels", "Vétéran", "Jouer 50 matchs suivis.", "shield", "silver", 50, "played"),
    Definition("veteran_200", "duels", "Pilier", "Jouer 200 matchs suivis.", "shield", "gold", 200, "played"),
    Definition("winner_10", "duels", "Vainqueur", "Remporter 10 matchs suivis.", "emoji_events", "bronze", 10, "wins"),
    Definition("winner_50", "duels", "Champion", "Remporter 50 matchs suivis.", "emoji_events", "silver", 50, "wins"),
    Definition("winner_100", "duels", "Légende", "Remporter 100 matchs suivis.", "emoji_events", "gold", 100, "wins"),
    Definition(
        "streak_3",
        "duels",
        "Sur sa lancée",
        "Enchaîner 3 victoires d'affilée.",
        "local_fire_department",
        "bronze",
        3,
        "best_streak",
    ),
    Definition(
        "streak_5",
        "duels",
        "En feu",
        "Enchaîner 5 victoires d'affilée.",
        "local_fire_department",
        "silver",
        5,
        "best_streak",
    ),
    Definition(
        "streak_10",
        "duels",
        "Invaincu",
        "Enchaîner 10 victoires d'affilée.",
        "local_fire_department",
        "gold",
        10,
        "best_streak",
    ),
    Definition(
        "six_domains",
        "duels",
        "Les six domaines",
        "Gagner avec des légendes couvrant les six domaines.",
        "hexagon",
        "prism",
        6,
        "domains",
    ),
    Definition(
        "giant_slayer",
        "duels",
        "Tueur de géants",
        "Battre un joueur comptant au moins 20 victoires de plus.",
        "swords",
        "prism",
        1,
        "giant",
    ),
    Definition(
        "marathon",
        "duels",
        "Marathon",
        "Remporter un match en deux manches gagnantes sur le score de 2–1.",
        "directions_run",
        "gold",
        1,
        "marathon",
    ),
    Definition(
        "collector_100",
        "collection",
        "Collectionneur",
        "Posséder 100 cartes différentes.",
        "style",
        "bronze",
        100,
        "unique_cards",
    ),
    Definition(
        "collector_500",
        "collection",
        "Grand collectionneur",
        "Posséder 500 cartes différentes.",
        "style",
        "silver",
        500,
        "unique_cards",
    ),
    Definition(
        "collector_1000",
        "collection",
        "Conservateur",
        "Posséder 1 000 cartes différentes.",
        "style",
        "gold",
        1000,
        "unique_cards",
    ),
    Definition(
        "set_complete",
        "collection",
        "Set complet",
        "Compléter un set à 100 % (hors impressions showcase).",
        "inventory_2",
        "prism",
        1,
        "sets_complete",
    ),
    Definition(
        "showcase_10",
        "collection",
        "Vitrine",
        "Posséder 10 impressions showcase (alt-art, overnumbered ou signature).",
        "auto_awesome",
        "silver",
        10,
        "showcase",
    ),
    Definition("architect_1", "decks", "Architecte", "Créer un premier deck.", "architecture", "bronze", 1, "decks"),
    Definition("architect_5", "decks", "Bâtisseur", "Créer 5 decks.", "architecture", "silver", 5, "decks"),
    Definition("architect_20", "decks", "Maître d'œuvre", "Créer 20 decks.", "architecture", "gold", 20, "decks"),
    Definition(
        "crowd_favorite",
        "decks",
        "Coup de cœur",
        "Recevoir 10 « j'aime » sur ses decks.",
        "favorite",
        "silver",
        10,
        "likes",
    ),
    Definition(
        "legal_eagle",
        "decks",
        "Dans les règles",
        "Publier un deck légal en tournoi.",
        "verified",
        "bronze",
        1,
        "legal_decks",
    ),
    Definition("sociable_5", "social", "Sociable", "Suivre 5 joueurs.", "group", "bronze", 5, "following"),
    Definition(
        "regular",
        "social",
        "Fidèle au poste",
        "Jouer un match suivi sur 30 jours différents.",
        "calendar_month",
        "gold",
        30,
        "days",
    ),
)

CATALOGUE_BY_KEY = {definition.key: definition for definition in CATALOGUE}

# Écart de victoires qui fait d'un adversaire un « géant ».
GIANT_GAP = 20
# Cartes de base d'un set : la complétion ignore les impressions showcase.
SHOWCASE_FLAGS = (Card.alternate_art.is_(True), Card.signature.is_(True), Card.overnumbered.is_(True))


def _base_card_clause():
    """Cartes comptant pour la complétion d'un set (ni showcase, ni variante)."""
    return (
        func.coalesce(Card.rarity, "") != "Showcase",
        Card.alternate_art.is_(False),
        Card.signature.is_(False),
        Card.overnumbered.is_(False),
    )


def _owned_card_ids(user: User):
    return select(CollectionItem.card_id).where(CollectionItem.user_id == user.id).distinct()


def _duel_metrics(db: Session, user: User) -> dict[str, int]:
    """Métriques de duels, sur les seuls matchs suivis comptés (confirmés ou abandonnés)."""
    # Import local : routers/play importe ce module (évaluation après confirm /
    # abandon), un import de module à module créerait un cycle.
    from .routers.play import COUNTED_MATCH_STATUSES, _counted, _streaks, _tally

    played_col, won_col = _tally(user)
    played, wins = db.execute(_counted(user).with_only_columns(played_col, won_col)).one()
    played, wins = int(played), int(wins)
    _current_streak, best_streak = _streaks(db, user)

    days = db.scalar(_counted(user).with_only_columns(func.count(func.distinct(func.date(Match.started_at))))) or 0

    opponent = aliased(MatchPlayer)
    versus = _counted(user).join(
        opponent, (opponent.match_id == MatchPlayer.match_id) & (opponent.user_id != MatchPlayer.user_id)
    )
    marathon = (
        db.scalar(
            versus.with_only_columns(func.count()).where(
                Match.mode == "match",
                Match.winner_user_id == user.id,
                MatchPlayer.rounds_won == 2,
                opponent.rounds_won == 1,
            )
        )
        or 0
    )

    # Domaines des légendes victorieuses : identifiants distincts en SQL, union
    # des domaines en mémoire (JSON non comparable côté Postgres).
    legend_ids = db.scalars(
        _counted(user)
        .with_only_columns(MatchPlayer.legend_card_id)
        .where(Match.winner_user_id == user.id, MatchPlayer.legend_card_id.is_not(None))
        .distinct()
    ).all()
    domains: set[str] = set()
    if legend_ids:
        for values in db.scalars(select(Card.domains).where(Card.id.in_(legend_ids))):
            domains.update(name for name in (values or []) if name != "Colorless")

    # « Tueur de géants » : approximation assumée — l'écart est mesuré sur les
    # totaux actuels des adversaires battus, pas sur leur score au moment du match.
    beaten = versus.with_only_columns(opponent.user_id).where(Match.winner_user_id == user.id).distinct()
    rival = aliased(MatchPlayer)
    best_rival = db.scalar(
        select(func.count())
        .select_from(rival)
        .join(Match, Match.id == rival.match_id)
        .where(
            rival.user_id.in_(beaten),
            Match.status.in_(COUNTED_MATCH_STATUSES),
            Match.winner_user_id == rival.user_id,
        )
        .group_by(rival.user_id)
        .order_by(func.count().desc())
        .limit(1)
    )

    return {
        "played": played,
        "wins": wins,
        "best_streak": best_streak,
        "days": int(days),
        "marathon": int(marathon),
        "domains": len(domains),
        "giant": 1 if best_rival is not None and int(best_rival) >= wins + GIANT_GAP else 0,
    }


def _collection_metrics(db: Session, user: User) -> dict[str, int]:
    """Cartes distinctes, impressions showcase et sets complétés (trois agrégats)."""
    owned = _owned_card_ids(user)
    unique_cards = (
        db.scalar(select(func.count(func.distinct(CollectionItem.card_id))).where(CollectionItem.user_id == user.id))
        or 0
    )
    showcase = db.scalar(select(func.count()).select_from(Card).where(Card.id.in_(owned), or_(*SHOWCASE_FLAGS))) or 0
    base = _base_card_clause()
    totals = dict(db.execute(select(Card.set_id, func.count()).where(*base).group_by(Card.set_id)).all())
    owned_by_set = dict(
        db.execute(select(Card.set_id, func.count()).where(*base, Card.id.in_(owned)).group_by(Card.set_id)).all()
    )
    complete = sum(1 for set_id, total in totals.items() if total and int(owned_by_set.get(set_id, 0)) >= int(total))
    return {"unique_cards": int(unique_cards), "showcase": int(showcase), "sets_complete": complete}


def _deck_metrics(db: Session, user: User) -> dict[str, int]:
    """Decks créés, « j'aime » reçus et decks publics légaux en tournoi."""
    decks = db.scalar(select(func.count()).select_from(Deck).where(Deck.owner_id == user.id)) or 0
    likes = db.scalar(select(func.coalesce(func.sum(Deck.likes_count), 0)).where(Deck.owner_id == user.id)) or 0
    # La légalité dépend des règles de construction : elle se vérifie en mémoire,
    # mais seulement sur les decks publics du joueur (jamais sur toute la table).
    publics = db.scalars(
        select(Deck).where(
            Deck.owner_id == user.id,
            Deck.is_public.is_(True),
            Deck.moderation_status == "published",
            Deck.format != "free",
        )
    ).all()
    legal = sum(
        1
        for deck in publics
        if all(check["ok"] for check in validate_deck([(entry.card, entry.qty) for entry in deck.cards]))
    )
    return {"decks": int(decks), "likes": int(likes), "legal_decks": legal}


def compute_metrics(db: Session, user: User) -> dict[str, int]:
    """Valeur courante de chaque métrique du catalogue, en SQL agrégé."""
    following = db.scalar(select(func.count()).select_from(Follow).where(Follow.follower_id == user.id)) or 0
    return {
        **_duel_metrics(db, user),
        **_collection_metrics(db, user),
        **_deck_metrics(db, user),
        "following": int(following),
    }


def _iso(moment: datetime | None) -> str | None:
    """SQLite restitue des datetimes naïfs (stockés en UTC) : on les recolle à UTC."""
    if moment is None:
        return None
    return (moment if moment.tzinfo else moment.replace(tzinfo=UTC)).isoformat()


def _achievement_out(definition: Definition, current: int, row: Achievement | None) -> dict:
    return {
        "key": definition.key,
        "family": definition.family,
        "title": definition.title,
        "description": definition.description,
        "icon": definition.icon,
        "tier": definition.tier,
        "threshold": definition.threshold,
        "current": current,
        "unlocked_at": _iso(row.unlocked_at) if row is not None else None,
    }


def _unlocked_rows(db: Session, user: User) -> dict[str, Achievement]:
    return {row.key: row for row in db.scalars(select(Achievement).where(Achievement.user_id == user.id))}


def evaluate_achievements(db: Session, user: User) -> list[dict]:
    """Enregistre les déblocages manquants et renvoie tout le catalogue à jour.

    La date de déblocage est posée une seule fois : une deuxième lecture
    retrouve la même valeur. Appelée à la lecture d'un profil et après un match
    compté ; le coût est celui des agrégats, indépendant du nombre de parties.
    """
    metrics = compute_metrics(db, user)
    unlocked = _unlocked_rows(db, user)
    now = utcnow()
    fresh = False
    for definition in CATALOGUE:
        current = metrics.get(definition.metric, 0)
        if current < definition.threshold or definition.key in unlocked:
            continue
        db.add(Achievement(user_id=user.id, key=definition.key, unlocked_at=now, progress=current))
        fresh = True
    if fresh:
        try:
            db.commit()
        except IntegrityError:  # course entre deux lectures simultanées du même profil
            db.rollback()
        unlocked = _unlocked_rows(db, user)
    return [_achievement_out(item, metrics.get(item.metric, 0), unlocked.get(item.key)) for item in CATALOGUE]


def unlocked_achievements(db: Session, user: User) -> list[dict]:
    """Hauts faits débloqués seulement, dans l'ordre de déblocage (profil public)."""
    rows = db.scalars(
        select(Achievement).where(Achievement.user_id == user.id).order_by(Achievement.unlocked_at, Achievement.id)
    ).all()
    payload = []
    for row in rows:
        definition = CATALOGUE_BY_KEY.get(row.key)
        if definition is None:  # clé retirée du catalogue : la ligne reste, on ne l'affiche plus
            continue
        payload.append(_achievement_out(definition, row.progress, row))
    return payload
