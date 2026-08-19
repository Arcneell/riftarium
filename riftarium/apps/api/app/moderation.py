"""Modération automatique minimale (V1).

Filtre lexical : un contenu contenant un terme interdit part en file « pending »
au lieu d'être publié. À terme : classification ML + détection d'images + revue humaine.
"""

import re
import unicodedata

BANNED_TERMS = [
    # insultes / toxicité (fr, en) — liste volontairement courte en V1
    "connard",
    "connasse",
    "encule",
    "fdp",
    "ntm",
    "pute",
    "salope",
    "batard",
    "fuck you",
    "asshole",
    "bitch",
    "retard",
    # arnaques / hors-charte : vente hors plateforme
    "paypal.me",
    "western union",
    "crypto wallet",
]

# Leet-speak et homoglyphes basiques (dont quelques lettres cyrilliques visuellement identiques).
_LEET = str.maketrans(
    {
        "0": "o",
        "1": "i",
        "3": "e",
        "4": "a",
        "@": "a",
        "$": "s",
        "!": "i",
        "а": "a",  # cyrillique
        "е": "e",
        "о": "o",
        "с": "c",
        "р": "p",
        "у": "y",
        "х": "x",
        "і": "i",
        "ѕ": "s",
    }
)

# Lettres isolées séparées par des espaces ou de la ponctuation : « c.o.n.n.a.r.d », « f d p ».
_SPACED_LETTERS = re.compile(r"\b(?:[a-z0-9][\s.,;:_*+·'\"-]+){2,}[a-z0-9]\b")
_SEPARATORS = re.compile(r"[\s.,;:_*+·'\"-]+")


def _fold(text: str) -> str:
    text = unicodedata.normalize("NFD", text.lower())
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    return text.translate(_LEET)


def _unspace(text: str) -> str:
    """Recolle les mots épelés lettre à lettre (« c o n n a r d » → « connard »)."""
    return _SPACED_LETTERS.sub(lambda match: _SEPARATORS.sub("", match.group()), text)


def review(text: str) -> str:
    """Renvoie le statut de modération : 'published' ou 'pending'."""
    folded = _fold(text or "")
    candidates = (folded, _unspace(folded))
    for term in BANNED_TERMS:
        if any(term in candidate for candidate in candidates):
            return "pending"
    return "published"
