from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import current_user, hash_password, make_token, verify_password
from ..db import get_db
from ..models import User
from ..schemas import LoginIn, RegisterIn, TokenOut

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/register", response_model=TokenOut, status_code=201)
def register(payload: RegisterIn, db: Session = Depends(get_db)):
    exists = db.scalar(
        select(User).where(
            (User.handle == payload.handle) | (User.email == payload.email)
        )
    )
    if exists:
        raise HTTPException(status_code=409, detail="Pseudo ou email déjà utilisé")
    user = User(
        handle=payload.handle,
        email=payload.email,
        password_hash=hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    return TokenOut(token=make_token(user), handle=user.handle)


@router.post("/login", response_model=TokenOut)
def login(payload: LoginIn, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Identifiants invalides")
    return TokenOut(token=make_token(user), handle=user.handle)


@router.get("/me")
def me(user: User = Depends(current_user)):
    return {"id": user.id, "handle": user.handle, "email": user.email}
