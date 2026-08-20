from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Response
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import mailer
from ..auth import (
    clear_session_cookie,
    consume_auth_token,
    current_user,
    dummy_verify,
    ensure_not_suspended,
    hash_password,
    issue_auth_token,
    make_token,
    needs_rehash,
    set_session_cookie,
    verify_password,
)
from ..db import get_db
from ..models import User, utcnow
from ..profiles import apply_profile, avatar_urls, delete_user_account, export_account, list_legend_avatars, user_out
from ..schemas import (
    AccountDelete,
    ForgotPasswordIn,
    LoginIn,
    PasswordChange,
    ProfilePatch,
    RegisterIn,
    ResetPasswordIn,
    SessionOut,
    VerifyEmailIn,
)
from ..security import enforce_same_origin, limit_auth, limit_auth_account, limit_email_send

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _session(db: Session, user: User, response: Response) -> SessionOut:
    set_session_cookie(response, make_token(user))
    return SessionOut(
        handle=user.handle,
        avatar_url=avatar_urls(db, [user]).get(user.id),
        is_admin=bool(user.is_admin),
    )


def _require_password(user: User, password: str | None) -> None:
    if not password or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=401, detail="Mot de passe actuel incorrect")


def _account_conflict(db: Session, handle: str, email: str) -> bool:
    return db.scalar(select(User).where((User.handle == handle) | (User.email == email))) is not None


@router.post("/register", response_model=SessionOut, status_code=201)
def register(
    payload: RegisterIn,
    response: Response,
    background: BackgroundTasks,
    db: Session = Depends(get_db),
    _: None = Depends(limit_auth),
    __: None = Depends(enforce_same_origin),
):
    if _account_conflict(db, payload.handle, payload.email):
        raise HTTPException(status_code=409, detail="Impossible de créer ce compte")
    user = User(
        handle=payload.handle,
        email=payload.email,
        password_hash=hash_password(payload.password),
        token_version=1,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:  # course entre la vérification et l'insertion
        db.rollback()
        raise HTTPException(status_code=409, detail="Impossible de créer ce compte") from None
    db.refresh(user)
    # Vérification d'adresse non bloquante : le compte est utilisable immédiatement.
    token = issue_auth_token(db, user, "verify")
    db.commit()
    background.add_task(mailer.send_verification_email, user.email, token)
    return _session(db, user, response)


@router.post("/login", response_model=SessionOut)
def login(
    payload: LoginIn,
    response: Response,
    db: Session = Depends(get_db),
    _: None = Depends(limit_auth),
    __: None = Depends(enforce_same_origin),
):
    limit_auth_account(payload.email)
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is None:
        dummy_verify()  # même coût qu'une vraie vérification : pas d'oracle temporel sur l'e-mail
        raise HTTPException(status_code=401, detail="Identifiants invalides")
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Identifiants invalides")
    ensure_not_suspended(user)  # après vérification du mot de passe : pas d'oracle sur l'e-mail
    if needs_rehash(user.password_hash):  # renforcement transparent des anciens hashes
        user.password_hash = hash_password(payload.password)
        db.commit()
    return _session(db, user, response)


@router.post("/logout", status_code=204)
def logout(response: Response, _user: User = Depends(current_user)):
    # Ne déconnecte que cet appareil : les autres sessions restent valides
    # (la révocation globale passe par le changement de mot de passe).
    clear_session_cookie(response)


@router.get("/me")
def me(user: User = Depends(current_user), db: Session = Depends(get_db)):
    return user_out(db, user, include_email=True, include_stats=True)


@router.get("/avatars")
def avatars(db: Session = Depends(get_db), _user: User = Depends(current_user)):
    return list_legend_avatars(db)


@router.patch("/me")
def update_me(
    payload: ProfilePatch,
    background: BackgroundTasks,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    data = payload.model_dump(exclude_unset=True)
    data.pop("current_password", None)
    if not data:
        raise HTTPException(status_code=400, detail="Aucune modification")
    if "handle" in data or "email" in data:
        _require_password(user, payload.current_password)
    email_changed = "email" in data and data["email"] != user.email
    apply_profile(db, user, data)
    try:
        db.commit()
    except IntegrityError:  # course entre la vérification d'unicité et l'écriture
        db.rollback()
        raise HTTPException(status_code=409, detail="Cette valeur est déjà utilisée") from None
    db.refresh(user)
    if email_changed:  # la nouvelle adresse repart non vérifiée : on renvoie un lien
        token = issue_auth_token(db, user, "verify")
        db.commit()
        background.add_task(mailer.send_verification_email, user.email, token)
    return user_out(db, user, include_email=True, include_stats=True)


@router.post("/password")
def change_password(
    payload: PasswordChange,
    response: Response,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
    _: None = Depends(enforce_same_origin),
):
    _require_password(user, payload.current_password)
    if payload.new_password == payload.current_password:
        raise HTTPException(status_code=400, detail="Le nouveau mot de passe doit être différent")
    user.password_hash = hash_password(payload.new_password)
    user.token_version += 1
    db.commit()
    db.refresh(user)
    return _session(db, user, response)


@router.post("/forgot-password", status_code=204)
def forgot_password(
    payload: ForgotPasswordIn,
    background: BackgroundTasks,
    db: Session = Depends(get_db),
    _: None = Depends(limit_auth),
    __: None = Depends(enforce_same_origin),
):
    """Demande de réinitialisation : répond 204 même si l'adresse est inconnue (anti-énumération)."""
    limit_email_send(payload.email)
    user = db.scalar(select(User).where(User.email == payload.email))
    if user is not None:
        token = issue_auth_token(db, user, "reset")
        db.commit()
        background.add_task(mailer.send_reset_email, user.email, token)


@router.post("/reset-password", status_code=204)
def reset_password(
    payload: ResetPasswordIn,
    db: Session = Depends(get_db),
    _: None = Depends(limit_auth),
    __: None = Depends(enforce_same_origin),
):
    """Choisit un nouveau mot de passe via le jeton reçu par e-mail (usage unique)."""
    user = consume_auth_token(db, payload.token, "reset")
    if user is None:
        raise HTTPException(status_code=400, detail="Lien invalide ou expiré — refaites une demande")
    user.password_hash = hash_password(payload.new_password)
    user.token_version += 1  # révoque toutes les sessions existantes
    db.commit()


@router.post("/verify-email", status_code=204)
def verify_email(
    payload: VerifyEmailIn,
    db: Session = Depends(get_db),
    _: None = Depends(limit_auth),
    __: None = Depends(enforce_same_origin),
):
    """Confirme l'adresse e-mail via le jeton reçu à l'inscription (usage unique)."""
    user = consume_auth_token(db, payload.token, "verify")
    if user is None:
        raise HTTPException(status_code=400, detail="Lien de vérification invalide ou expiré")
    if user.email_verified_at is None:
        user.email_verified_at = utcnow()
    db.commit()


@router.post("/resend-verification", status_code=204)
def resend_verification(
    background: BackgroundTasks,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
    _: None = Depends(limit_auth),
    __: None = Depends(enforce_same_origin),
):
    """Renvoie l'e-mail de vérification à l'utilisateur connecté."""
    if user.email_verified_at is not None:
        raise HTTPException(status_code=400, detail="Adresse déjà vérifiée")
    limit_email_send(user.email)
    token = issue_auth_token(db, user, "verify")
    db.commit()
    background.add_task(mailer.send_verification_email, user.email, token)


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
