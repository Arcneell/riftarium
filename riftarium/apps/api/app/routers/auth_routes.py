from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import (
    clear_session_cookie,
    current_user,
    hash_password,
    make_token,
    set_session_cookie,
    verify_password,
)
from ..db import get_db
from ..models import User
from ..profiles import apply_profile, avatar_urls, delete_user_account, export_account, list_legend_avatars, user_out
from ..schemas import AccountDelete, LoginIn, PasswordChange, ProfilePatch, RegisterIn, TokenOut
from ..security import limit_auth

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _token(db: Session, user: User, response: Response) -> TokenOut:
    payload = TokenOut(token=make_token(user), handle=user.handle, avatar_url=avatar_urls(db, [user]).get(user.id))
    set_session_cookie(response, payload.token)
    return payload


def _require_password(user: User, password: str | None) -> None:
    if not password or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=401, detail="Mot de passe actuel incorrect")


@router.post("/register", response_model=TokenOut, status_code=201)
def register(
    payload: RegisterIn,
    response: Response,
    db: Session = Depends(get_db),
    _: None = Depends(limit_auth),
):
    exists = db.scalar(select(User).where((User.handle == payload.handle) | (User.email == payload.email)))
    if exists:
        raise HTTPException(status_code=409, detail="Impossible de créer ce compte")
    user = User(
        handle=payload.handle,
        email=payload.email,
        password_hash=hash_password(payload.password),
        token_version=1,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return _token(db, user, response)


@router.post("/login", response_model=TokenOut)
def login(
    payload: LoginIn,
    response: Response,
    db: Session = Depends(get_db),
    _: None = Depends(limit_auth),
):
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Identifiants invalides")
    return _token(db, user, response)


@router.post("/logout", status_code=204)
def logout(response: Response, user: User = Depends(current_user), db: Session = Depends(get_db)):
    user.token_version += 1
    db.commit()
    clear_session_cookie(response)


@router.get("/me")
def me(user: User = Depends(current_user), db: Session = Depends(get_db)):
    return user_out(db, user, include_email=True, include_stats=True)


@router.get("/avatars")
def avatars(db: Session = Depends(get_db), _user: User = Depends(current_user)):
    return list_legend_avatars(db)


@router.patch("/me")
def update_me(payload: ProfilePatch, user: User = Depends(current_user), db: Session = Depends(get_db)):
    data = payload.model_dump(exclude_unset=True)
    data.pop("current_password", None)
    if not data:
        raise HTTPException(status_code=400, detail="Aucune modification")
    if "handle" in data or "email" in data:
        _require_password(user, payload.current_password)
    apply_profile(db, user, data)
    db.commit()
    db.refresh(user)
    return user_out(db, user, include_email=True, include_stats=True)


@router.post("/password")
def change_password(
    payload: PasswordChange,
    response: Response,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    _require_password(user, payload.current_password)
    if payload.new_password == payload.current_password:
        raise HTTPException(status_code=400, detail="Le nouveau mot de passe doit être différent")
    user.password_hash = hash_password(payload.new_password)
    user.token_version += 1
    db.commit()
    db.refresh(user)
    return _token(db, user, response)


@router.get("/export")
def export_me(user: User = Depends(current_user), db: Session = Depends(get_db)):
    return export_account(db, user)


@router.delete("/me", status_code=204)
def delete_me(
    payload: AccountDelete,
    response: Response,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    _require_password(user, payload.password)
    if payload.handle != user.handle:
        raise HTTPException(status_code=400, detail="Le pseudo ne correspond pas")
    delete_user_account(db, user)
    db.commit()
    clear_session_cookie(response)
