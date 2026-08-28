from datetime import UTC, date, datetime

from sqlalchemy import (
    JSON,
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base


def utcnow() -> datetime:
    return datetime.now(UTC)


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    handle: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    bio: Mapped[str] = mapped_column(String(280), default="")
    avatar_card_id: Mapped[str | None] = mapped_column(String(32), nullable=True)
    token_version: Mapped[int] = mapped_column(Integer, default=1)
    email_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # Notification e-mail des décisions de modération sur ses decks (désactivable
    # depuis le profil). N'est envoyée que si l'adresse est vérifiée.
    notify_moderation: Mapped[bool] = mapped_column(Boolean, default=True)
    # Droits d'administration : pilotés exclusivement par ADMIN_EMAILS au démarrage
    # (voir routers/admin.py) — jamais modifiables via l'API.
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    # Suspension : bloque login et sessions tant que suspended_until est dans le futur.
    # Une suspension expirée est simplement ignorée (pas de nettoyage nécessaire).
    suspended_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    suspension_reason: Mapped[str | None] = mapped_column(String(280), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class AuthToken(Base):
    """Jeton à usage unique envoyé par e-mail (vérification d'adresse ou reset).

    Seul le hash SHA-256 est stocké : une fuite de la base ne permet pas de
    rejouer les liens. Le jeton est supprimé à l'usage (single-use).
    """

    __tablename__ = "auth_tokens"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    purpose: Mapped[str] = mapped_column(String(8))  # verify | reset
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class CardSet(Base):
    __tablename__ = "sets"

    set_id: Mapped[str] = mapped_column(String(8), primary_key=True)
    name: Mapped[str] = mapped_column(String(64))
    card_count: Mapped[int] = mapped_column(Integer, default=0)
    published_on: Mapped[str | None] = mapped_column(String(32), nullable=True)


class Card(Base):
    __tablename__ = "cards"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)  # id Riftcodex (unique, variantes incluses)
    riftbound_id: Mapped[str] = mapped_column(String(32), index=True)  # ex: ogn-209-298 (partagé entre variantes)
    name: Mapped[str] = mapped_column(String(128), index=True)
    collector_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    set_id: Mapped[str] = mapped_column(ForeignKey("sets.set_id"), index=True)
    type: Mapped[str] = mapped_column(String(24), index=True)
    supertype: Mapped[str | None] = mapped_column(String(24), nullable=True)
    rarity: Mapped[str | None] = mapped_column(String(24), index=True)
    domains: Mapped[list] = mapped_column(JSON, default=list)
    energy: Mapped[int | None] = mapped_column(Integer, nullable=True)
    might: Mapped[int | None] = mapped_column(Integer, nullable=True)
    power: Mapped[int | None] = mapped_column(Integer, nullable=True)
    text_plain: Mapped[str | None] = mapped_column(Text, nullable=True)
    text_flavour: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    # Empreinte perceptuelle du visuel (dHash 512 bits en hex, voir app/imagehash.py).
    # NULL tant qu'elle n'a pas été calculée (POST /api/admin/cards/hashes) ou après
    # un changement d'image_url à la sync.
    image_hash: Mapped[str | None] = mapped_column(String(128), nullable=True)
    artist: Mapped[str | None] = mapped_column(String(128), nullable=True)
    orientation: Mapped[str | None] = mapped_column(String(16), nullable=True)
    tags: Mapped[list] = mapped_column(JSON, default=list)
    alternate_art: Mapped[bool] = mapped_column(Boolean, default=False)
    signature: Mapped[bool] = mapped_column(Boolean, default=False)
    overnumbered: Mapped[bool] = mapped_column(Boolean, default=False)
    updated_on: Mapped[str | None] = mapped_column(String(40), nullable=True)
    # Prix TCGplayer (voir app/prices.py). tcgplayer_id vient de Riftcodex (sync ou
    # backfill) ; price_usd = marketPrice de la version « Normal », sinon « Foil »
    # à défaut ; price_foil_usd = marketPrice « Foil ». NULL tant qu'inconnu.
    tcgplayer_id: Mapped[str | None] = mapped_column(String(16), nullable=True, index=True)
    price_usd: Mapped[float | None] = mapped_column(Float, nullable=True)
    price_foil_usd: Mapped[float | None] = mapped_column(Float, nullable=True)


class PriceHistory(Base):
    """Prix du marché (USD) d'une carte, une ligne par jour : historique des cours."""

    __tablename__ = "price_history"
    __table_args__ = (UniqueConstraint("day", "card_id", name="uq_price_history_day_card"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    day: Mapped[date] = mapped_column(Date, index=True)
    card_id: Mapped[str] = mapped_column(ForeignKey("cards.id"), index=True)
    market_usd: Mapped[float] = mapped_column(Float)


class AppState(Base):
    """Petit stockage clé/valeur applicatif (taux de change, jour du dernier refresh…)."""

    __tablename__ = "app_state"

    key: Mapped[str] = mapped_column(String(64), primary_key=True)
    value: Mapped[str] = mapped_column(String(255))


class CollectionItem(Base):
    """Un lot d'exemplaires : même carte, même état, même langue."""

    __tablename__ = "collection_items"
    __table_args__ = (UniqueConstraint("user_id", "card_id", "condition", "lang", name="uq_collection_entry"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    card_id: Mapped[str] = mapped_column(ForeignKey("cards.id"), index=True)
    qty: Mapped[int] = mapped_column(Integer, default=1)
    condition: Mapped[str] = mapped_column(String(8), default="NM")
    lang: Mapped[str] = mapped_column(String(8), default="EN")

    card: Mapped[Card] = relationship(lazy="joined")


class WishlistItem(Base):
    """Carte recherchée par un joueur (liste d'achats), avec la quantité visée."""

    __tablename__ = "wishlist_items"
    __table_args__ = (UniqueConstraint("user_id", "card_id", name="uq_wishlist_entry"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    card_id: Mapped[str] = mapped_column(ForeignKey("cards.id"), index=True)
    qty: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    card: Mapped[Card] = relationship(lazy="joined")


class Deck(Base):
    __tablename__ = "decks"
    # Index composite pour les listes publiques (communauté) filtrées par statut de modération.
    __table_args__ = (Index("ix_decks_public_moderation", "is_public", "moderation_status"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(80))
    description: Mapped[str] = mapped_column(Text, default="")
    format: Mapped[str] = mapped_column(String(16), default="tournament")  # tournament | free
    is_public: Mapped[bool] = mapped_column(Boolean, default=False)
    moderation_status: Mapped[str] = mapped_column(String(16), default="published")  # published | pending | rejected
    likes_count: Mapped[int] = mapped_column(Integer, default=0)
    views_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    owner: Mapped[User] = relationship(lazy="joined")
    cards: Mapped[list["DeckCard"]] = relationship(cascade="all, delete-orphan", lazy="selectin")
    like_entries: Mapped[list["DeckLike"]] = relationship(cascade="all, delete-orphan")
    view_entries: Mapped[list["DeckView"]] = relationship(cascade="all, delete-orphan")


class DeckCard(Base):
    __tablename__ = "deck_cards"
    __table_args__ = (UniqueConstraint("deck_id", "card_id", name="uq_deck_card"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    deck_id: Mapped[int] = mapped_column(ForeignKey("decks.id"), index=True)
    card_id: Mapped[str] = mapped_column(ForeignKey("cards.id"), index=True)
    qty: Mapped[int] = mapped_column(Integer, default=1)

    card: Mapped[Card] = relationship(lazy="joined")


class DeckLike(Base):
    __tablename__ = "deck_likes"
    __table_args__ = (UniqueConstraint("deck_id", "user_id", name="uq_deck_like"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    deck_id: Mapped[int] = mapped_column(ForeignKey("decks.id"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)


class PageHit(Base):
    """Fréquentation agrégée et anonyme : compteurs par jour et par section.

    Aucune donnée personnelle n'est persistée (ni IP, ni identifiant, ni user-agent) :
    seuls des compteurs jour × section, conformes à l'engagement « zéro traceur ».
    Les visiteurs uniques (ligne réservée section="site") sont dédupliqués via une
    empreinte salée éphémère stockée uniquement dans Redis (voir routers/metrics.py).
    """

    __tablename__ = "page_hits"
    __table_args__ = (UniqueConstraint("day", "section", name="uq_page_hit_day_section"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    day: Mapped[date] = mapped_column(Date, index=True)
    section: Mapped[str] = mapped_column(String(32))
    hits: Mapped[int] = mapped_column(Integer, default=0)
    uniques: Mapped[int] = mapped_column(Integer, default=0)


class DeckView(Base):
    """Visite unique d'un deck public : un compteur par visiteur (compte ou IP)."""

    __tablename__ = "deck_views"
    __table_args__ = (UniqueConstraint("deck_id", "visitor_key", name="uq_deck_view"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    deck_id: Mapped[int] = mapped_column(ForeignKey("decks.id"), index=True)
    visitor_key: Mapped[str] = mapped_column(String(40), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Room(Base):
    """Salon de partie suivie : un code à 6 caractères, deux sièges, 2 h de validité.

    `match_id` n'est volontairement pas une clé étrangère : `matches.room_id`
    pointe déjà sur `rooms`, et le cycle empêcherait la création du schéma
    (SQLAlchemy ne sait pas ordonner deux tables mutuellement liées).
    `host_id` n'en est pas une non plus : les salons et les matchs survivent à
    la suppression d'un compte, ils sont seulement anonymisés (cf. profiles.py).
    """

    __tablename__ = "rooms"

    id: Mapped[int] = mapped_column(primary_key=True)
    code: Mapped[str] = mapped_column(String(8), unique=True, index=True)
    host_id: Mapped[int] = mapped_column(Integer, index=True)
    mode: Mapped[str] = mapped_column(String(8), default="duel")  # duel | match
    status: Mapped[str] = mapped_column(String(16), default="open")  # open | playing | finished | cancelled
    match_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    version: Mapped[int] = mapped_column(Integer, default=1)


class RoomPlayer(Base):
    """Un siège du salon : 0 pour l'hôte, 1 pour l'invité.

    `deck_id` n'est pas une clé étrangère : la suppression d'un deck ne doit ni
    échouer ni effacer la partie — le deck est alors simplement inconnu (null).
    """

    __tablename__ = "room_players"
    __table_args__ = (
        UniqueConstraint("room_id", "user_id", name="uq_room_player"),
        UniqueConstraint("room_id", "seat", name="uq_room_seat"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    room_id: Mapped[int] = mapped_column(ForeignKey("rooms.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    seat: Mapped[int] = mapped_column(Integer, default=0)
    legend_card_id: Mapped[str | None] = mapped_column(ForeignKey("cards.id"), nullable=True)
    deck_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ready: Mapped[bool] = mapped_column(Boolean, default=False)


class Match(Base):
    """Match suivi : le serveur ne résout aucune règle, il transporte l'instantané saisi.

    `state` est le compteur courant, `result` le score final. `version` s'incrémente
    à chaque modification et sert au contrôle de concurrence (polling des clients).
    """

    __tablename__ = "matches"

    id: Mapped[int] = mapped_column(primary_key=True)
    room_id: Mapped[int | None] = mapped_column(ForeignKey("rooms.id"), nullable=True, index=True)
    mode: Mapped[str] = mapped_column(String(8), default="duel")
    # live | awaiting_confirmation | confirmed | disputed | abandoned
    status: Mapped[str] = mapped_column(String(24), default="live", index=True)
    host_id: Mapped[int] = mapped_column(Integer, index=True)
    first_player_id: Mapped[int] = mapped_column(Integer)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # NULL quand le gagnant a supprimé son compte (le match reste, anonymisé).
    winner_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    state: Mapped[dict] = mapped_column(JSON, default=dict)
    version: Mapped[int] = mapped_column(Integer, default=1)
    result: Mapped[dict | None] = mapped_column(JSON, nullable=True)


class MatchPlayer(Base):
    """Participation d'un joueur à un match : légende, deck et score figés à la fin.

    Ces lignes sont supprimées avec le compte : le match subsiste, l'adversaire
    y voit alors `opponent: null`.
    """

    __tablename__ = "match_players"
    __table_args__ = (UniqueConstraint("match_id", "user_id", name="uq_match_player"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    match_id: Mapped[int] = mapped_column(ForeignKey("matches.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    seat: Mapped[int] = mapped_column(Integer, default=0)
    legend_card_id: Mapped[str | None] = mapped_column(ForeignKey("cards.id"), nullable=True)
    deck_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    score: Mapped[int] = mapped_column(Integer, default=0)
    rounds_won: Mapped[int] = mapped_column(Integer, default=0)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
