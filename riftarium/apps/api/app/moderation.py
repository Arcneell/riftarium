"""Modération automatique minimale (V1).

Filtre lexical : un contenu contenant un terme interdit part en file « pending »
au lieu d'être publié. À terme : classification ML + détection d'images + revue humaine.
"""

import re
import unicodedata

BANNED_TERMS = [
    # insultes / toxicité (fr, en) — liste volontairement courte en V1
    "connard", "connasse", "encule", "fdp", "ntm", "pute", "salope", "batard",
    "fuck you", "asshole", "bitch", "retard",
    # arnaques / hors-charte : vente hors plateforme
    "paypal.me", "western union", "crypto wallet",
]

_WORD = re.compile(r"[a-z0-9.\- ]+")


def _fold(text: str) -> str:
    text = unicodedata.normalize("NFD", text.lower())
    return "".join(c for c in text if unicodedata.category(c) != "Mn")


def review(text: str) -> str:
    """Renvoie le statut de modération : 'published' ou 'pending'."""
    folded = _fold(text or "")
    for term in BANNED_TERMS:
        if term in folded:
            return "pending"
    return "published"
