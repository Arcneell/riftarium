"""Assemblage d'un deck de tournoi à partir d'une légende et du pool de cartes."""

from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import Card
from .validation import MAIN_TYPES
from .variants import copy_family


def is_base(card: Card) -> bool:
    return not (card.alternate_art or card.signature or card.overnumbered)


def domains_of(card: Card) -> set[str]:
    return {d for d in (card.domains or []) if d != "Colorless"}


def load_pool(db: Session) -> list[Card]:
    """Une carte par famille de jeu, version de base de préférence."""
    all_cards = db.scalars(select(Card).order_by(Card.set_id, Card.collector_number, Card.id)).all()
    families: dict[str, Card] = {}
    for card in all_cards:
        key = copy_family(card)
        current = families.get(key)
        if current is None or (is_base(card) and not is_base(current)):
            families[key] = card
    return list(families.values())


def legends_in(pool: Sequence[Card]) -> list[Card]:
    return [card for card in pool if card.type == "Legend"]


def main_candidates(pool: Sequence[Card], legend: Card) -> list[Card]:
    allowed = domains_of(legend)
    return [card for card in pool if card.type in MAIN_TYPES and domains_of(card) <= allowed]


def has_champion(legend: Card, candidates: Sequence[Card]) -> bool:
    tags = set(legend.tags or [])
    return not tags or any(tags & set(card.tags or []) for card in candidates)


def copy_cap(card: Card) -> int:
    return 1 if "[unique]" in (card.text_plain or "").lower() else 3


def assemble_list(
    pool: Sequence[Card],
    legend: Card,
    *,
    owned: dict[str, int] | None = None,
    prefer_owned: bool = False,
    shuffle: bool = False,
    rng=None,
) -> list[tuple[Card, int]]:
    """Construit légende + 3 champs + 12 runes + jusqu'à 40 cartes principales."""
    owned = owned or {}

    def owned_qty(card: Card) -> int:
        return owned.get(copy_family(card), 0)

    def ownership_rank(card: Card) -> int:
        return -int(owned_qty(card) > 0) if prefer_owned else int(owned_qty(card) > 0)

    battlefields = [card for card in pool if card.type == "Battlefield"]
    if shuffle and rng is not None:
        battlefields = list(battlefields)
        rng.shuffle(battlefields)
    else:
        battlefields = sorted(battlefields, key=lambda c: (ownership_rank(c), c.set_id or "", c.collector_number or 0))
    battlefields = battlefields[:3]

    rune_pool = sorted(
        (card for card in pool if card.type == "Rune" and domains_of(card) <= domains_of(legend)),
        key=lambda c: (ownership_rank(c), c.set_id or "", c.collector_number or 0),
    )
    if shuffle and rng is not None and rune_pool:
        rune_pool = list(rune_pool)
        rng.shuffle(rune_pool)

    rune_entries: list[tuple[Card, int]] = []
    rune_total = 0
    for rune in rune_pool:
        if rune_total >= 12:
            break
        qty = min(12 - rune_total, owned_qty(rune)) if prefer_owned else 12 - rune_total
        if qty > 0:
            rune_entries.append((rune, qty))
            rune_total += qty
    if rune_total < 12 and rune_pool:
        top_up = 12 - rune_total
        existing = next((entry for entry in rune_entries if entry[0].id == rune_pool[0].id), None)
        if existing:
            rune_entries[rune_entries.index(existing)] = (existing[0], existing[1] + top_up)
        else:
            rune_entries.append((rune_pool[0], top_up))

    tags = set(legend.tags or [])

    def is_champion(card: Card) -> bool:
        return bool(tags & set(card.tags or []))

    candidates = list(main_candidates(pool, legend))
    if shuffle and rng is not None:
        champions = [card for card in candidates if is_champion(card)]
        others = [card for card in candidates if not is_champion(card)]
        rng.shuffle(others)
        candidates = champions + others
    else:
        candidates.sort(
            key=lambda c: (
                -int(is_champion(c)),
                ownership_rank(c),
                c.energy if c.energy is not None else 99,
                c.set_id or "",
                c.collector_number or 0,
            )
        )

    main_entries: list[tuple[Card, int]] = []
    main_total = 0
    for card in candidates:
        if main_total >= 40:
            break
        qty = min(copy_cap(card), owned_qty(card)) if prefer_owned else copy_cap(card)
        if qty > 0:
            main_entries.append((card, qty))
            main_total += qty
    if main_total < 40:
        for card in candidates:
            if main_total >= 40:
                break
            already = next((entry for entry in main_entries if entry[0].id == card.id), None)
            room = copy_cap(card) - (already[1] if already else 0)
            qty = min(room, 40 - main_total)
            if qty <= 0:
                continue
            if already:
                main_entries[main_entries.index(already)] = (card, already[1] + qty)
            else:
                main_entries.append((card, qty))
            main_total += qty

    entries = [(legend, 1)]
    entries.extend((card, 1) for card in battlefields)
    entries.extend((card, min(qty, 12)) for card, qty in rune_entries)
    entries.extend(main_entries)
    return entries
