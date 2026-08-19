import hashlib
import hmac
import os
from datetime import UTC, datetime, timedelta

import jwt
from fastapi import Depends, HTTPException, Request, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .config import settings
from .db import get_db
from .models import User
from .security import SESSION_COOKIE

bearer = HTTPBearer(auto_error=False)

# Ancien format « salt$digest » : paramètres implicites de l'époque.
_LEGACY_SCRYPT = (2**14, 8, 1)

_dummy_hash: str | None = None


def _scrypt_target() -> tuple[int, int, int]:
    return (settings.scrypt_n, settings.scrypt_r, settings.scrypt_p)


def _scrypt(password: str, salt: bytes, params: tuple[int, int, int]) -> bytes:
    n, r, p = params
    # hashlib.scrypt exige maxmem > ~128*n*r octets : on prend une marge confortable.
    return hashlib.scrypt(password.encode(), salt=salt, n=n, r=r, p=p, maxmem=128 * r * n * 2)


def _parse_hash(stored: str) -> tuple[tuple[int, int, int], bytes, str] | None:
    """Décode « n$r$p$salt$digest » ou l'ancien format « salt$digest »."""
    parts = stored.split("$")
    try:
        if len(parts) == 2:
            return _LEGACY_SCRYPT, bytes.fromhex(parts[0]), parts[1]
        if len(parts) == 5:
            return (int(parts[0]), int(parts[1]), int(parts[2])), bytes.fromhex(parts[3]), parts[4]
    except ValueError:
        return None
    return None


def hash_password(password: str) -> str:
    params = _scrypt_target()
    salt = os.urandom(16)
    digest = _scrypt(password, salt, params)
    n, r, p = params
    return f"{n}${r}${p}${salt.hex()}${digest.hex()}"


def verify_password(password: str, stored: str) -> bool:
    parsed = _parse_hash(stored)
    if parsed is None:
        return False
    params, salt, digest_hex = parsed
    digest = _scrypt(password, salt, params)
    return hmac.compare_digest(digest.hex(), digest_hex)


def needs_rehash(stored: str) -> bool:
    """Vrai si le hash stocké utilise des paramètres plus faibles que la cible actuelle."""
    parsed = _parse_hash(stored)
    if parsed is None:
        return False
    (n, _r, _p), _salt, _digest = parsed
    return n < settings.scrypt_n


def dummy_verify() -> None:
    """Vérification factice pour égaliser le temps de réponse quand l'e-mail est inconnu."""
    global _dummy_hash
    if _dummy_hash is None:
        _dummy_hash = hash_password("riftarium-dummy-password")
    verify_password("riftarium-dummy-mismatch", _dummy_hash)


def make_token(user: User) -> str:
    payload = {
        "sub": str(user.id),
        "handle": user.handle,
        "ver": user.token_version,
        "exp": datetime.now(UTC) + timedelta(hours=settings.jwt_ttl_hours),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def set_session_cookie(response: Response, token: str) -> None:
    response.set_cookie(
        key=SESSION_COOKIE,
        value=token,
        httponly=True,
        samesite="lax",
        secure=settings.cookie_secure,
        max_age=settings.jwt_ttl_hours * 3600,
        path="/",
    )


def clear_session_cookie(response: Response) -> None:
    response.delete_cookie(SESSION_COOKIE, path="/")


def _raw_token(request: Request, credentials: HTTPAuthorizationCredentials | None) -> str | None:
    if credentials is not None:
        return credentials.credentials
    cookie = request.cookies.get(SESSION_COOKIE)
    return cookie or None


def _user_from_token(token: str, db: Session) -> User | None:
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    except jwt.PyJWTError:
        return None
    try:
        user = db.get(User, int(payload["sub"]))
    except (TypeError, ValueError, KeyError):
        return None
    if user is None:
        return None
    try:
        version = int(payload["ver"])
    except (KeyError, TypeError, ValueError):
        return None
    if version != user.token_version:
        return None
    return user


def current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    token = _raw_token(request, credentials)
    if token is None:
        raise HTTPException(status_code=401, detail="Authentification requise")
    user = _user_from_token(token, db)
    if user is None:
        raise HTTPException(status_code=401, detail="Jeton invalide ou expiré")
    return user


def optional_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> User | None:
    token = _raw_token(request, credentials)
    if token is None:
        return None
    return _user_from_token(token, db)
