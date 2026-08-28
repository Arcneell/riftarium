from typing import Annotated, Literal

from pydantic import (
    AfterValidator,
    BaseModel,
    BeforeValidator,
    EmailStr,
    Field,
    SerializerFunctionWrapHandler,
    field_validator,
    model_serializer,
    model_validator,
)

HANDLE_PATTERN = r"^[A-Za-z0-9_\-]+$"

# E-mail normalisé en minuscules : l'unicité des comptes et l'attribution du
# drapeau admin (ADMIN_EMAILS, comparé en minuscules) doivent voir la même
# chaîne quelle que soit la casse saisie. Sans ça, « Foo@x.com » et « foo@x.com »
# sont deux comptes distincts, dont l'un pourrait hériter des droits admin.
NormEmail = Annotated[EmailStr, AfterValidator(lambda v: v.lower())]

# Mots de passe ultra-communs (listes fr/en publiques) : refusés à l'inscription
# et au changement de mot de passe, quelle que soit la casse.
COMMON_PASSWORDS = frozenset(
    {
        "password",
        "password1",
        "password123",
        "passw0rd",
        "p@ssw0rd",
        "12345678",
        "123456789",
        "1234567890",
        "123123123",
        "987654321",
        "11111111",
        "00000000",
        "azertyuiop",
        "azerty123",
        "qwertyuiop",
        "qwerty123",
        "qwerty12345",
        "1q2w3e4r5t",
        "motdepasse",
        "motdepasse1",
        "monmotdepasse",
        "iloveyou1",
        "iloveyou123",
        "sunshine1",
        "princess1",
        "football1",
        "baseball1",
        "welcome1",
        "welcome123",
        "letmein123",
        "trustno1",
        "dragon123",
        "monkey123",
        "superman1",
        "batman123",
        "pokemon123",
        "starwars1",
        "michael1",
        "jennifer1",
        "chocolat1",
        "doudou123",
        "soleil123",
        "bonjour123",
        "marseille13",
        "aaaaaaaa",
        "abcd1234",
        "abc123456",
        "a1b2c3d4",
        "asdfghjkl",
        "wxcvbn123",
        "computer1",
        "internet1",
        "changeme1",
        "secret123",
        "admin123",
        "administrator",
        "root1234",
        "test1234",
        "temp1234",
        "loulou123",
        "chouchou1",
    }
)

# Valeurs alignées sur le front (riftarium/apps/web/src/api.js : CONDITIONS et LANGS).
CONDITIONS = frozenset({"MT", "NM", "EX", "GD", "LP", "PL", "PO"})
LANGS = frozenset({"EN", "FR", "DE", "ES", "IT", "JP", "KO", "ZH"})


def _check_common_password(password: str) -> str:
    if password.strip().lower() in COMMON_PASSWORDS:
        raise ValueError("Ce mot de passe est trop courant : choisissez-en un plus original.")
    return password


def _norm_condition(value):
    if not isinstance(value, str):
        return value
    normalized = value.strip().upper()
    if normalized not in CONDITIONS:
        raise ValueError(f"État inconnu : {value} (valeurs possibles : {', '.join(sorted(CONDITIONS))})")
    return normalized


def _norm_lang(value):
    if not isinstance(value, str):
        return value
    normalized = value.strip().upper()
    if normalized not in LANGS:
        raise ValueError(f"Langue inconnue : {value} (valeurs possibles : {', '.join(sorted(LANGS))})")
    return normalized


Condition = Annotated[str, BeforeValidator(_norm_condition)]
Lang = Annotated[str, BeforeValidator(_norm_lang)]


class RegisterIn(BaseModel):
    handle: str = Field(min_length=3, max_length=32, pattern=HANDLE_PATTERN)
    email: NormEmail
    password: str = Field(min_length=8, max_length=128)
    accept_terms: bool
    confirm_age: bool

    @field_validator("password")
    @classmethod
    def reject_common_password(cls, value: str) -> str:
        return _check_common_password(value)

    @model_validator(mode="after")
    def require_consents(self):
        if not self.accept_terms or not self.confirm_age:
            raise ValueError("L'inscription exige d'accepter les conditions et de confirmer avoir au moins 15 ans.")
        return self


class LoginIn(BaseModel):
    email: NormEmail
    # Borné comme à l'inscription : sans plafond, une saisie d'un mégaoctet part
    # dans scrypt (n=2^17) à chaque tentative.
    password: str = Field(max_length=128)


class SessionOut(BaseModel):
    """Réponse d'authentification : le jeton circule via le cookie HttpOnly pour le web,
    et en plus dans le corps (champ `token`) pour le client mobile natif."""

    handle: str
    avatar_url: str | None = None
    # Permet au front d'afficher l'entrée Administration dès la connexion (le
    # serveur reste seul juge : toutes les routes admin revérifient la session).
    is_admin: bool = False
    # Présent uniquement pour le client mobile (en-tête « X-Riftarium-Client: mobile »),
    # qui ne peut pas s'appuyer sur le cookie ; absent de la réponse sinon.
    token: str | None = None

    @model_serializer(mode="wrap")
    def _hide_absent_token(self, handler: SerializerFunctionWrapHandler) -> dict:
        """Retire complètement la clé `token` quand il n'y en a pas : la réponse servie
        au web reste identique à l'existant (pas même un `token: null`)."""
        data = handler(self)
        if self.token is None:
            data.pop("token", None)
        return data


class ProfilePatch(BaseModel):
    handle: str | None = Field(default=None, min_length=3, max_length=32, pattern=HANDLE_PATTERN)
    email: NormEmail | None = None
    bio: str | None = Field(default=None, max_length=280)
    avatar_card_id: str | None = Field(default=None, max_length=32)
    # Préférence e-mail (décisions de modération) : modifiable sans mot de passe.
    notify_moderation: bool | None = None
    current_password: str | None = Field(default=None, max_length=128)


class PasswordChange(BaseModel):
    current_password: str = Field(max_length=128)
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def reject_common_password(cls, value: str) -> str:
        return _check_common_password(value)


class ForgotPasswordIn(BaseModel):
    email: NormEmail


class ResetPasswordIn(BaseModel):
    """Le nouveau mot de passe suit les mêmes règles qu'à l'inscription."""

    token: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def reject_common_password(cls, value: str) -> str:
        return _check_common_password(value)


class VerifyEmailIn(BaseModel):
    token: str = Field(min_length=1, max_length=128)


class AccountDelete(BaseModel):
    password: str = Field(max_length=128)
    handle: str = Field(min_length=3, max_length=32)


class CollectionPut(BaseModel):
    qty: int = Field(ge=0, le=999)
    condition: Condition = "NM"
    lang: Lang = "EN"


class CollectionEntryIn(BaseModel):
    qty: int = Field(ge=1, le=999)
    condition: Condition = "NM"
    lang: Lang = "EN"


class CollectionEntryPatch(BaseModel):
    qty: int | None = Field(default=None, ge=0, le=999)
    condition: Condition | None = None
    lang: Lang | None = None


class CollectionBulk(BaseModel):
    card_ids: list[str] = Field(min_length=1, max_length=500)
    qty: int | None = Field(default=None, ge=0, le=999)
    qty_delta: int | None = Field(default=None, ge=-999, le=999)
    condition: Condition | None = None
    lang: Lang | None = None
    remove: bool = False

    @model_validator(mode="after")
    def exclusive_operations(self):
        actions = [self.qty is not None, self.qty_delta is not None, self.remove]
        if sum(actions) > 1:
            raise ValueError("qty, qty_delta et remove sont mutuellement exclusifs : choisissez une seule opération.")
        return self


class WishlistPut(BaseModel):
    """Quantité visée pour une carte de la wishlist (l'upsert écrase la valeur)."""

    qty: int = Field(ge=1, le=99)


class DeckCardIn(BaseModel):
    card_id: str
    qty: int = Field(ge=1, le=12)


class ExampleDeckIn(BaseModel):
    mode: str = Field(default="owned", pattern=r"^(owned|discover)$")


class DeckIn(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    description: str = Field(default="", max_length=2000)
    format: str = Field(default="tournament", pattern=r"^(tournament|free)$")
    is_public: bool = False
    cards: list[DeckCardIn] = Field(default_factory=list, max_length=150)


class ModerationIn(BaseModel):
    """Décision de modération admin sur un deck en attente."""

    status: Literal["approved", "rejected"]


class HitIn(BaseModel):
    """Ping de fréquentation anonyme : uniquement le nom d'écran visité."""

    section: str = Field(min_length=1, max_length=64)


class SuspendIn(BaseModel):
    """Suspension de compte par un administrateur (durée en heures + motif affiché)."""

    hours: int = Field(gt=0, le=24 * 3650)  # « définitif » = très grande durée côté front
    reason: str = Field(min_length=1, max_length=280)

    @field_validator("reason")
    @classmethod
    def strip_reason(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Le motif de suspension est obligatoire.")
        return value


class RoomCreate(BaseModel):
    """Création d'un salon de partie suivie (v1 : formats à deux joueurs)."""

    mode: Literal["duel", "match"] = "duel"


class RoomPlayerIn(BaseModel):
    """Choix personnels dans le salon : légende, deck et « prêt » (PUT = remplacement)."""

    legend_card_id: str | None = Field(default=None, max_length=32)
    deck_id: int | None = Field(default=None, ge=1)
    ready: bool = False


class RoomStartIn(BaseModel):
    """Lancement du match : le tirage au sort se fait côté client, on transmet le résultat."""

    first_player_id: int = Field(ge=1)


# Bornes larges : le compteur est un pense-bête, le serveur n'arbitre pas les
# règles — il refuse seulement l'absurde (négatifs, valeurs hors d'échelle).
CounterValue = Annotated[int, Field(ge=0, le=999)]


class MatchState(BaseModel):
    """Instantané du compteur. Les clés des dictionnaires sont des `user_id` en chaîne."""

    round: int = Field(ge=1, le=99)
    turn: int = Field(ge=1, le=999)
    active_user_id: int = Field(ge=1)
    scores: dict[str, CounterValue]
    xp: dict[str, CounterValue]
    rounds_won: dict[str, CounterValue]

    @model_validator(mode="after")
    def coherent_players(self):
        keys = set(self.scores)
        if not keys or set(self.xp) != keys or set(self.rounds_won) != keys:
            raise ValueError("scores, xp et rounds_won doivent porter sur les mêmes joueurs.")
        if any(not key.isdigit() for key in keys):
            raise ValueError("Les clés du compteur sont des identifiants de joueur (user_id en chaîne).")
        if str(self.active_user_id) not in keys:
            raise ValueError("active_user_id doit désigner l'un des joueurs du compteur.")
        return self


class MatchStateIn(BaseModel):
    """Mise à jour du compteur avec contrôle de version optimiste (`version` = version lue)."""

    version: int = Field(ge=1)
    state: MatchState


class MatchFinishIn(BaseModel):
    """Fin de match déclarée par l'hôte : gagnant et scores finaux (même forme que `state`)."""

    winner_user_id: int = Field(ge=1)
    result: MatchState
