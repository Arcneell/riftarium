"""Jeu de données communautaire pour tester filtres, likes et vues en local."""

from datetime import UTC, datetime, timedelta
from random import Random

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from .auth import hash_password
from .deckbuild import assemble_list, has_champion, legends_in, load_pool, main_candidates
from .models import CollectionItem, Deck, DeckCard, DeckLike, DeckView, User
from .moderation import review

DEMO_PASSWORD = "demodemo1"
DEMO_EMAIL_DOMAIN = "riftarium.demo"
DEMO_AUTHORS = [
    "Kael",
    "Nyra",
    "Vexil",
    "Runehound",
    "Hexsmith",
    "NoxianSteel",
    "IoniaMist",
    "ZaunSpark",
    "DemaciaShield",
    "Freljord",
    "ShadowIsle",
    "PiltoverArch",
]
FAN_COUNT = 30
STYLES = ["Agro", "Midrange", "Contrôle", "Tempo", "Combo", "Ramp"]
PITCH = [
    "Liste de tournoi, curve basse, pression dès le tour 2.",
    "Plan de jeu : tenir le milieu puis refermer avec le champion élu.",
    "Beaucoup de réactions. Fragile si on se fait bannir la légende.",
    "Version budget, jouable presque telle quelle.",
    "Techée contre les decks de Fureur qui tournent en ce moment.",
    "Un peu greedy, mais ça passe des boards impossibles à rattraper.",
    "Side à affiner — les champs de bataille ne sont pas figés.",
    "Idée reprise d'un match de qualifier, retravaillée à la table.",
]


def _short_legend(name: str) -> str:
    return name.replace(" — ", " - ").split(" - ", 1)[0].strip() or name


def _wipe_demo(db: Session) -> int:
    users = db.scalars(select(User).where(User.email.like(f"%@{DEMO_EMAIL_DOMAIN}"))).all()
    if not users:
        return 0
    ids = [user.id for user in users]
    deck_ids = list(db.scalars(select(Deck.id).where(Deck.owner_id.in_(ids))).all())
    if deck_ids:
        db.execute(delete(DeckLike).where(DeckLike.deck_id.in_(deck_ids)))
        db.execute(delete(DeckView).where(DeckView.deck_id.in_(deck_ids)))
        db.execute(delete(DeckCard).where(DeckCard.deck_id.in_(deck_ids)))
        db.execute(delete(Deck).where(Deck.id.in_(deck_ids)))
    db.execute(delete(DeckLike).where(DeckLike.user_id.in_(ids)))
    db.execute(delete(CollectionItem).where(CollectionItem.user_id.in_(ids)))
    db.execute(delete(DeckView).where(DeckView.visitor_key.in_([f"u:{uid}" for uid in ids])))
    db.execute(delete(User).where(User.id.in_(ids)))
    db.flush()
    return len(ids)


def seed_community(db: Session, *, reset: bool = True, limit: int | None = None) -> dict:
    """Remplit la communauté : auteurs, decks publics, likes et vues uniques."""
    pool = load_pool(db)
    if not pool:
        raise ValueError("Aucune carte en base : lancez une synchronisation")

    legends = [card for card in legends_in(pool) if has_champion(card, main_candidates(pool, card))] or legends_in(pool)
    if not legends:
        raise ValueError("Aucune légende disponible")
    legends = sorted(legends, key=lambda card: card.name)
    if limit:
        legends = legends[: max(1, limit)]

    removed = _wipe_demo(db) if reset else 0
    password_hash = hash_password(DEMO_PASSWORD)
    portrait_ids = [card.id for card in legends if card.image_url]

    authors: list[User] = []
    for index, handle in enumerate(DEMO_AUTHORS):
        user = db.scalar(select(User).where(User.handle == handle))
        if user is None:
            user = User(
                handle=handle,
                email=f"{handle.lower()}@{DEMO_EMAIL_DOMAIN}",
                password_hash=password_hash,
                avatar_card_id=portrait_ids[index % len(portrait_ids)] if portrait_ids else None,
            )
            db.add(user)
        authors.append(user)

    fans: list[User] = []
    for index in range(1, FAN_COUNT + 1):
        handle = f"fan_{index:02d}"
        user = db.scalar(select(User).where(User.handle == handle))
        if user is None:
            user = User(
                handle=handle,
                email=f"{handle}@{DEMO_EMAIL_DOMAIN}",
                password_hash=password_hash,
            )
            db.add(user)
        fans.append(user)
    db.flush()

    jobs: list[tuple[object, bool]] = [(legend, False) for legend in legends]
    extras = min(24, max(0, len(legends) // 3))
    jobs.extend((legend, True) for legend in legends[:extras])

    created = 0
    now = datetime.now(UTC)
    likers = fans + authors

    for rank, (legend, variant) in enumerate(jobs):
        rng = Random(f"{legend.id}:{int(variant)}")
        entries = assemble_list(pool, legend, shuffle=variant, rng=rng if variant else None)
        if not entries:
            continue
        owner = authors[rank % len(authors)]
        style = STYLES[rank % len(STYLES)]
        short = _short_legend(legend.name)
        name = f"{style} · {short}" if not variant else f"{style} · {short} (v2)"
        when = now - timedelta(days=rng.randint(0, 80), hours=rng.randint(0, 23), minutes=rng.randint(0, 59))
        if rank >= len(jobs) - 8:
            when = now - timedelta(hours=rng.randint(1, 36))
        likes = 0 if rank >= len(jobs) - 8 else max(0, int(36 * (0.88**rank) + rng.randint(0, 4)))
        likes = min(likes, len(likers) - 1)
        views = likes * rng.randint(12, 48) + rng.randint(3, 90)

        deck = Deck(
            owner_id=owner.id,
            name=name[:80],
            description=PITCH[rank % len(PITCH)],
            format="free" if variant and rank % 5 == 0 else "tournament",
            is_public=True,
            moderation_status=review(name),
            likes_count=likes,
            views_count=views,
            created_at=when,
            updated_at=when,
        )
        for card, qty in entries:
            deck.cards.append(DeckCard(card_id=card.id, qty=qty))
        db.add(deck)
        db.flush()

        chosen = [user for user in likers if user.id != owner.id]
        rng.shuffle(chosen)
        for user in chosen[:likes]:
            db.add(DeckLike(deck_id=deck.id, user_id=user.id))
        created += 1

    db.commit()
    return {
        "removed_demo_users": removed,
        "authors": len(authors),
        "fans": len(fans),
        "decks": created,
        "login": {
            "handle": DEMO_AUTHORS[0],
            "email": f"{DEMO_AUTHORS[0].lower()}@{DEMO_EMAIL_DOMAIN}",
            "password": DEMO_PASSWORD,
        },
    }
