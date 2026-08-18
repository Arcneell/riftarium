from pydantic import BaseModel, EmailStr, Field


class RegisterIn(BaseModel):
    handle: str = Field(min_length=3, max_length=32, pattern=r"^[A-Za-z0-9_\-]+$")
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class TokenOut(BaseModel):
    token: str
    handle: str


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
