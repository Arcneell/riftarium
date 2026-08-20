from typing import Annotated, Literal

from pydantic import BaseModel, BeforeValidator, EmailStr, Field, field_validator, model_validator

HANDLE_PATTERN = r"^[A-Za-z0-9_\-]+$"

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
    email: EmailStr
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
    email: EmailStr
    password: str


class SessionOut(BaseModel):
    """Réponse d'authentification : le jeton circule uniquement via le cookie HttpOnly."""

    handle: str
    avatar_url: str | None = None
    # Permet au front d'afficher l'entrée Administration dès la connexion (le
    # serveur reste seul juge : toutes les routes admin revérifient la session).
    is_admin: bool = False


class ProfilePatch(BaseModel):
    handle: str | None = Field(default=None, min_length=3, max_length=32, pattern=HANDLE_PATTERN)
    email: EmailStr | None = None
    bio: str | None = Field(default=None, max_length=280)
    avatar_card_id: str | None = None
    current_password: str | None = None


class PasswordChange(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def reject_common_password(cls, value: str) -> str:
        return _check_common_password(value)


class ForgotPasswordIn(BaseModel):
    email: EmailStr


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
    password: str
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
