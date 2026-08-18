from datetime import UTC, datetime

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    ForeignKey,
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
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )


class CardSet(Base):
    __tablename__ = "sets"

    set_id: Mapped[str] = mapped_column(String(8), primary_key=True)
    name: Mapped[str] = mapped_column(String(64))
    card_count: Mapped[int] = mapped_column(Integer, default=0)
    published_on: Mapped[str | None] = mapped_column(String(32), nullable=True)


class Card(Base):
    __tablename__ = "cards"

    id: Mapped[str] = mapped_column(
        String(32), primary_key=True
    )  # id Riftcodex (unique, variantes incluses)
    riftbound_id: Mapped[str] = mapped_column(
        String(32), index=True
    )  # ex: ogn-209-298 (partagé entre variantes)
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
    artist: Mapped[str | None] = mapped_column(String(128), nullable=True)
    orientation: Mapped[str | None] = mapped_column(String(16), nullable=True)
    tags: Mapped[list] = mapped_column(JSON, default=list)
    alternate_art: Mapped[bool] = mapped_column(Boolean, default=False)
    signature: Mapped[bool] = mapped_column(Boolean, default=False)
    overnumbered: Mapped[bool] = mapped_column(Boolean, default=False)
    updated_on: Mapped[str | None] = mapped_column(String(40), nullable=True)


class CollectionItem(Base):
    __tablename__ = "collection_items"
    __table_args__ = (
        UniqueConstraint("user_id", "card_id", name="uq_collection_user_card"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    card_id: Mapped[str] = mapped_column(ForeignKey("cards.id"), index=True)
    qty: Mapped[int] = mapped_column(Integer, default=1)
    condition: Mapped[str] = mapped_column(String(8), default="NM")
    lang: Mapped[str] = mapped_column(String(8), default="EN")

    card: Mapped[Card] = relationship(lazy="joined")


class Deck(Base):
    __tablename__ = "decks"

    id: Mapped[int] = mapped_column(primary_key=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(80))
    description: Mapped[str] = mapped_column(Text, default="")
    format: Mapped[str] = mapped_column(
        String(16), default="tournament"
    )  # tournament | free
    is_public: Mapped[bool] = mapped_column(Boolean, default=False)
    moderation_status: Mapped[str] = mapped_column(
        String(16), default="published"
    )  # published | pending | rejected
    likes_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )

    owner: Mapped[User] = relationship(lazy="joined")
    cards: Mapped[list["DeckCard"]] = relationship(
        cascade="all, delete-orphan", lazy="selectin"
    )


class DeckCard(Base):
    __tablename__ = "deck_cards"
    __table_args__ = (UniqueConstraint("deck_id", "card_id", name="uq_deck_card"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    deck_id: Mapped[int] = mapped_column(ForeignKey("decks.id"), index=True)
    card_id: Mapped[str] = mapped_column(ForeignKey("cards.id"))
    qty: Mapped[int] = mapped_column(Integer, default=1)

    card: Mapped[Card] = relationship(lazy="joined")


class DeckLike(Base):
    __tablename__ = "deck_likes"
    __table_args__ = (UniqueConstraint("deck_id", "user_id", name="uq_deck_like"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    deck_id: Mapped[int] = mapped_column(ForeignKey("decks.id"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
