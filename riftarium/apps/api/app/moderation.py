"""Modération automatique (V2 lexicale).

Filtre lexical : un contenu contenant un terme interdit part en file « pending »
au lieu d'être publié. Deux modes de détection :

- BANNED_WORDS : mots entiers uniquement (frontières de mot après normalisation).
  Obligatoire pour les termes courts ou contenus dans des mots légitimes
  (« con » dans « concombre », « pute » dans « computer », « cul » dans « calcul »,
  « salope » dans « salopette », « bite » dans « orbite »…).
- BANNED_FRAGMENTS : termes longs et sans homonymie, aussi détectés à l'intérieur
  d'un mot (« xXconnardXx », « superfucker »).

La normalisation (accents, leet-speak, homoglyphes, lettres épelées) s'applique
avant le matching. À terme : classification ML + détection d'images + revue humaine.
"""

import re
import unicodedata

# ---------------------------------------------------------------------------
# Lexique. Les termes sont écrits en minuscules NON accentuées (forme normalisée) ;
# les expressions multi-mots sont aussi testées recollées (« niquetamere »).
# ---------------------------------------------------------------------------

# Mots entiers uniquement : courts, ou substrings de mots légitimes.
BANNED_WORDS = [
    # --- insultes et vulgarité (fr) ---
    "con",
    "cons",
    "conne",
    "connes",
    "connard",
    "connards",
    "connasse",
    "connasses",
    "abruti",
    "abrutis",
    "abrutie",
    "cretin",
    "cretins",
    "cretine",
    "debile",
    "debiles",
    "mongol",
    "mongols",
    "attarde",
    "attardes",
    "attardee",
    "trisomique",
    "trisomiques",
    "batard",
    "batards",
    "batarde",
    "salaud",
    "salauds",
    "salope",
    "salopes",
    "pouffiasse",
    "poufiasse",
    "pouffiasses",
    "poufiasses",
    "grognasse",
    "grognasses",
    "pute",
    "putes",
    "putain",
    "putains",
    "enfoire",
    "enfoires",
    "enfoiree",
    "ordure",
    "ordures",
    "raclure",
    "raclures",
    "fumier",
    "fumiers",
    "cul",
    "culs",
    "bite",
    "bites",
    "couille",
    "couilles",
    "chatte",
    "chattes",
    "nichons",
    "branleur",
    "branleurs",
    "branleuse",
    "branlette",
    "suceur",
    "suceurs",
    "suceuse",
    "suceuses",
    "merdeux",
    "merdeuse",
    "fdp",
    "ntm",
    "tg",
    "vtff",
    "ta gueule",
    "ferme ta gueule",
    "nique ta mere",
    "nique ta race",
    "niquer",
    "fils de pute",
    "fille de pute",
    "trou du cul",
    "va te faire",
    "va crever",
    "sale con",
    # --- slurs (fr) ---
    "pd",
    "pede",
    "pedes",
    "pedale",
    "pedales",
    "tapette",
    "tapettes",
    "tarlouze",
    "tarlouzes",
    "tafiole",
    "tafioles",
    "gouine",
    "gouines",
    "travelo",
    "travelos",
    "negre",
    "negres",
    "negresse",
    "negro",
    "negros",
    "bougnoule",
    "bougnoules",
    "bicot",
    "bicots",
    "youpin",
    "youpins",
    "chinetoque",
    "chinetoques",
    "bamboula",
    "bamboulas",
    "niakoue",
    "niakoues",
    "boche",
    "boches",
    "sale arabe",
    "sale noir",
    "sale noire",
    "sale blanc",
    "sale juif",
    "sale juive",
    "sale race",
    # --- insultes et vulgarité (en) ---
    "fuck",
    "fucks",
    "fucked",
    "fucking",
    "fck",
    "fcking",
    "shit",
    "shitty",
    "shits",
    "ass",
    "asses",
    "arse",
    "bitch",
    "bitches",
    "bastard",
    "bastards",
    "cunt",
    "cunts",
    "dick",
    "dicks",
    "cock",
    "cocks",
    "pussy",
    "pussies",
    "whore",
    "whores",
    "slut",
    "sluts",
    "twat",
    "twats",
    "wanker",
    "wankers",
    "prick",
    "pricks",
    "douchebag",
    "douchebags",
    "jackass",
    "dumbass",
    "retarded",
    "rape",
    "raped",
    "rapist",
    "porn",
    "porno",
    "cum",
    "stfu",
    "kys",
    "kill yourself",
    "go die",
    "fuck you",
    "fuck off",
    "piece of shit",
    "son of a bitch",
    # --- slurs (en) ---
    "fag",
    "fags",
    "dyke",
    "dykes",
    "kike",
    "kikes",
    "chink",
    "chinks",
    "spic",
    "spics",
    "wetback",
    "wetbacks",
    "tranny",
    "trannies",
    "coon",
    "coons",
    "nazi",
    "nazis",
    "hitler",
    "pedo",
    "pedos",
    "pedophile",
    "pedophiles",
]

# Aussi détectés en fragment (à l'intérieur d'un mot) : longs, sans homonymie
# connue en français ou en anglais.
BANNED_FRAGMENTS = [
    "connard",
    "connasse",
    "encule",
    "enculer",
    "enculee",
    "pouffiasse",
    "niquetamere",
    "niquetarace",
    "filsdepute",
    "filledepute",
    "troudocul",
    "trouducul",
    "motherfuck",
    "asshole",
    "shithead",
    "dickhead",
    "faggot",
    "nigger",
    "nigga",
    "cocksucker",
    "pedophile",
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


def _word_pattern(terms: list[str]) -> re.Pattern:
    """Regex « mots entiers » : chaque espace du terme accepte espaces ou ponctuation."""
    parts = [re.escape(term).replace("\\ ", r"[\s.,;:_*+·'\"-]+") for term in terms]
    return re.compile(r"(?<![a-z0-9])(?:" + "|".join(parts) + r")(?![a-z0-9])")


_WORDS_RE = _word_pattern(BANNED_WORDS)
# Les expressions multi-mots doivent aussi être reconnues recollées (« taguele » non,
# mais « niquetamere » oui) : variante sans espaces, matchée en mot entier.
_JOINED_RE = _word_pattern(sorted({term.replace(" ", "") for term in BANNED_WORDS if " " in term}))


def review(text: str) -> str:
    """Renvoie le statut de modération : 'published' ou 'pending'."""
    folded = _fold(text or "")
    candidates = (folded, _unspace(folded))
    for candidate in candidates:
        if _WORDS_RE.search(candidate) or _JOINED_RE.search(candidate):
            return "pending"
        if any(fragment in candidate for fragment in BANNED_FRAGMENTS):
            return "pending"
    return "published"
