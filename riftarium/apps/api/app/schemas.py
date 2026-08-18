from pydantic import BaseModel, EmailStr, Field, model_validator

HANDLE_PATTERN = r"^[A-Za-z0-9_\-]+$"


class RegisterIn(BaseModel):
    handle: str = Field(min_length=3, max_length=32, pattern=HANDLE_PATTERN)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    accept_terms: bool
    confirm_age: bool

    @model_validator(mode="after")
    def require_consents(self):
        if not self.accept_terms or not self.confirm_age:
            raise ValueError("L'inscription exige d'accepter les conditions et de confirmer avoir au moins 15 ans.")
        return self


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class TokenOut(BaseModel):
    token: str
    handle: str
    avatar_url: str | None = None


class ProfilePatch(BaseModel):
    handle: str | None = Field(default=None, min_length=3, max_length=32, pattern=HANDLE_PATTERN)
    email: EmailStr | None = None
    bio: str | None = Field(default=None, max_length=280)
    avatar_card_id: str | None = None
    current_password: str | None = None


class PasswordChange(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)


class AccountDelete(BaseModel):
    password: str
    handle: str = Field(min_length=3, max_length=32)


class CollectionPut(BaseModel):
    qty: int = Field(ge=0, le=999)
    condition: str = Field(default="NM", max_length=8)
    lang: str = Field(default="EN", max_length=8)


class CollectionEntryIn(BaseModel):
    qty: int = Field(ge=1, le=999)
    condition: str = Field(default="NM", max_length=8)
    lang: str = Field(default="EN", max_length=8)


class CollectionEntryPatch(BaseModel):
    qty: int | None = Field(default=None, ge=0, le=999)
    condition: str | None = Field(default=None, max_length=8)
    lang: str | None = Field(default=None, max_length=8)


class CollectionBulk(BaseModel):
    card_ids: list[str] = Field(min_length=1, max_length=500)
    qty: int | None = Field(default=None, ge=0, le=999)
    qty_delta: int | None = Field(default=None, ge=-999, le=999)
    condition: str | None = Field(default=None, max_length=8)
    lang: str | None = Field(default=None, max_length=8)
    remove: bool = False


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
    cards: list[DeckCardIn] = []
