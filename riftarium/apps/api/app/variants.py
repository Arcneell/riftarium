"""Familles de variantes d'une même carte (art alternatif, signature, étoile).

ogn-037a-298 / ogn-037*-298 → famille ogn-037-298. Les ids promo/rune (ven-sp4-006, ven-r04) restent uniques.
"""

import re

from sqlalchemy import func, or_

from .models import Card

_VARIANT_ID_RE = re.compile(r"^([a-z0-9]+)-(\d+)([a-z*]?)-(\d+)$", re.IGNORECASE)


def variant_family(riftbound_id: str | None) -> str:
    ident = (riftbound_id or "").strip().lower()
    match = _VARIANT_ID_RE.match(ident)
    if not match:
        return ident
    set_id, number, _marker, suffix = match.groups()
    return f"{set_id}-{number}-{suffix}"


def variant_id_clause(family: str):
    """Correspond à l'id de base et aux variantes à une lettre (a, *)."""
    lowered = func.lower(Card.riftbound_id)
    clauses = [lowered == family]
    prefix, sep, suffix = family.rpartition("-")
    if sep and "-" in prefix:
        clauses.append(lowered.like(f"{prefix}_-{suffix}"))
    return or_(*clauses)
