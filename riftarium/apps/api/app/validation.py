"""Validation des decks selon les règles officielles de tournoi Riftbound.

Chaque contrôle référence le chapitre des règles de construction (doc officiel).
Le mode « free » ne bloque rien : les contrôles sont renvoyés à titre indicatif.
"""

from .models import Card

MAIN_TYPES = {"Unit", "Spell", "Gear"}


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
        battlefield_count == 3
        and all(q == 1 for _, q in battlefields)
        and distinct_battlefields,
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

    over = [c.name for c, q in main if q > 3]
    add(
        "copies",
        not over,
        "Maximum 3 exemplaires par carte"
        if not over
        else f"Plus de 3 exemplaires : {', '.join(over)}",
    )

    if legend_count == 1:
        legend_domains = {d for d in (legends[0][0].domains or []) if d != "Colorless"}
        illegal = [
            c.name
            for c, _ in main + runes
            if {d for d in (c.domains or []) if d != "Colorless"} - legend_domains
        ]
        add(
            "domains",
            not illegal,
            "Domaines conformes à la légende"
            if not illegal
            else f"Hors domaines de la légende : {', '.join(sorted(set(illegal))[:5])}",
        )
    else:
        add("domains", False, "Domaines non vérifiables sans légende unique")

    return checks
