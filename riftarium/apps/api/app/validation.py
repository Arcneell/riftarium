"""Validation des decks selon les règles officielles de tournoi Riftbound.

Chaque contrôle référence le chapitre des règles de construction (doc officiel).
Le mode « free » ne bloque rien : les contrôles sont renvoyés à titre indicatif.
"""

from .models import Card
from .variants import variant_family

MAIN_TYPES = {"Unit", "Spell", "Gear"}


def _family(card: Card) -> str:
    return variant_family(card.riftbound_id) or card.id


def _is_unique(card: Card) -> bool:
    return "[unique]" in (card.text_plain or "").lower()


def validate_deck(entries: list[tuple[Card, int]]) -> list[dict]:
    legends = [(c, q) for c, q in entries if c.type == "Legend"]
    battlefields = [(c, q) for c, q in entries if c.type == "Battlefield"]
    runes = [(c, q) for c, q in entries if c.type == "Rune"]
    main = [(c, q) for c, q in entries if c.type in MAIN_TYPES]

    checks: list[dict] = []

    def add(rule: str, ok: bool, message: str) -> None:
        checks.append({"rule": rule, "ok": ok, "message": message})

    legend_count = sum(q for _, q in legends)
    add(
        "legend",
        legend_count == 1,
        f"Exactement 1 légende ({legend_count} actuellement)",
    )

    battlefield_count = sum(q for _, q in battlefields)
    distinct_battlefields = len(battlefields) == len({c.id for c, _ in battlefields})
    add(
        "battlefields",
        battlefield_count == 3 and all(q == 1 for _, q in battlefields) and distinct_battlefields,
        f"3 champs de bataille distincts ({battlefield_count} actuellement)",
    )

    rune_count = sum(q for _, q in runes)
    add("runes", rune_count == 12, f"12 runes ({rune_count} actuellement)")

    main_count = sum(q for _, q in main)
    add(
        "main_size",
        main_count >= 40,
        f"Deck principal : 40 cartes minimum ({main_count} actuellement)",
    )

    # Règle 103.2.b : 3 exemplaires max par carte, toutes variantes confondues (même famille d'id).
    by_family: dict[str, dict] = {}
    for card, qty in main:
        slot = by_family.setdefault(_family(card), {"name": card.name, "qty": 0})
        slot["qty"] += qty
        slot["name"] = min(slot["name"], card.name, key=len)  # nom de base plutôt que « (Alternate Art) »
    over = sorted({slot["name"] for slot in by_family.values() if slot["qty"] > 3})
    add(
        "copies",
        not over,
        "Maximum 3 exemplaires par carte" if not over else f"Plus de 3 exemplaires : {', '.join(over[:5])}",
    )

    # Mot-clé [Unique] : un seul exemplaire dans tout le deck (règle 800).
    unique_totals: dict[str, dict] = {}
    for card, qty in entries:
        if not _is_unique(card):
            continue
        slot = unique_totals.setdefault(_family(card), {"name": card.name, "qty": 0})
        slot["qty"] += qty
        slot["name"] = min(slot["name"], card.name, key=len)
    unique_over = sorted({slot["name"] for slot in unique_totals.values() if slot["qty"] > 1})
    add(
        "unique",
        not unique_over,
        "Cartes [Unique] en un seul exemplaire"
        if not unique_over
        else f"[Unique] en plusieurs exemplaires : {', '.join(unique_over[:5])}",
    )

    if legend_count == 1:
        legend_card = legends[0][0]
        legend_domains = {d for d in (legend_card.domains or []) if d != "Colorless"}
        illegal = [
            c.name for c, _ in main + runes if {d for d in (c.domains or []) if d != "Colorless"} - legend_domains
        ]
        add(
            "domains",
            not illegal,
            "Domaines conformes à la légende"
            if not illegal
            else f"Hors domaines de la légende : {', '.join(sorted(set(illegal))[:5])}",
        )

        # Règle 103.2.a.2 : le deck principal contient le champion élu (tag partagé avec la légende).
        legend_tags = set(legend_card.tags or [])
        if legend_tags:
            has_champion = any(legend_tags & set(c.tags or []) for c, _ in main)
            tag_label = " / ".join(sorted(legend_tags))
            add(
                "champion",
                has_champion,
                f"Champion élu présent ({tag_label})"
                if has_champion
                else f"Aucune carte {tag_label} dans le deck principal (champion élu requis)",
            )
    else:
        add("domains", False, "Domaines non vérifiables sans légende unique")

    return checks
