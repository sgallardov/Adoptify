"""Códigos de verificación por correo (HU-I): creación, envío, reenvío y validación.

El código es de 6 dígitos al azar (secrets) y nunca se guarda: en la BD queda su HMAC-SHA256 con la
SECRET_KEY y el id del desafío, así que una filtración de la tabla no sirve para adivinarlo. Cada desafío
vence a los LOGIN_CODE_MINUTES y se borra tras LOGIN_CODE_MAX_ATTEMPTS intentos fallidos.
"""

import hashlib
import hmac
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.login_challenge import LoginChallenge
from app.models.user import User
from app.services.email import EmailError, send_verification_code

RESTART_LOGIN = "Inicia sesión otra vez para recibir un código nuevo."


def generate_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_code(challenge_id: str, code: str) -> str:
    return hmac.new(settings.SECRET_KEY.encode(), f"{challenge_id}:{code}".encode(), hashlib.sha256).hexdigest()


def mask_email(email: str) -> str:
    """'matias.adopter@gmail.com' -> 'm***r@gmail.com': para decir a dónde llegó sin mostrarlo entero."""
    name, _, domain = email.partition("@")
    hidden = name[0] + "***" + (name[-1] if len(name) > 2 else "")
    return f"{hidden}@{domain}"


def _now() -> datetime:
    return datetime.now(timezone.utc)


def challenge_info(challenge: LoginChallenge, email: str) -> dict:
    """Lo que recibe el cliente: el id del desafío y a dónde se envió, nunca el código."""
    return {
        "challenge_id": challenge.id,
        "email_hint": mask_email(email),
        "expires_in_minutes": settings.LOGIN_CODE_MINUTES,
        "resend_in_seconds": settings.LOGIN_CODE_RESEND_SECONDS,
    }


async def _send(db: AsyncSession, challenge: LoginChallenge, user: User, code: str) -> None:
    """Guarda el desafío y envía el correo; si el correo falla, no queda nada guardado."""
    try:
        await db.flush()
        await send_verification_code(user.email, code, challenge.purpose, user.full_name)
        await db.commit()
    except EmailError as exc:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No pudimos enviar el código a tu correo. Inténtalo nuevamente en unos minutos.",
        ) from exc
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo generar el código de verificación.") from exc


async def start_challenge(db: AsyncSession, user: User, purpose: str) -> LoginChallenge:
    """Crea un desafío nuevo (anula los anteriores del mismo tipo) y envía el código al correo."""
    try:
        await db.execute(
            delete(LoginChallenge).where(LoginChallenge.user_id == user.id, LoginChallenge.purpose == purpose)
        )
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo generar el código de verificación.") from exc

    challenge_id = str(uuid.uuid4())
    code = generate_code()
    challenge = LoginChallenge(
        id=challenge_id,
        user_id=user.id,
        purpose=purpose,
        code_hash=hash_code(challenge_id, code),
        expires_at=_now() + timedelta(minutes=settings.LOGIN_CODE_MINUTES),
        attempts=0,
        last_sent_at=_now(),
    )
    db.add(challenge)
    await _send(db, challenge, user, code)
    return challenge


async def _get(db: AsyncSession, challenge_id: str) -> LoginChallenge | None:
    try:
        return await db.get(LoginChallenge, challenge_id)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo validar el código.") from exc


async def _discard(db: AsyncSession, challenge: LoginChallenge) -> None:
    try:
        await db.delete(challenge)
        await db.commit()
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo validar el código.") from exc


async def resend_code(db: AsyncSession, challenge_id: str) -> tuple[LoginChallenge, User]:
    """Nuevo código para el mismo desafío (el anterior deja de servir), como máximo uno por minuto."""
    challenge = await _get(db, challenge_id)
    if challenge is None or challenge.expires_at <= _now():
        if challenge is not None:
            await _discard(db, challenge)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"El código ya no es válido. {RESTART_LOGIN}")

    wait = settings.LOGIN_CODE_RESEND_SECONDS - (_now() - challenge.last_sent_at).total_seconds()
    if wait > 0:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Espera {int(wait) + 1} segundos para pedir otro código.",
        )

    user = await db.get(User, challenge.user_id)
    code = generate_code()
    challenge.code_hash = hash_code(challenge.id, code)
    challenge.expires_at = _now() + timedelta(minutes=settings.LOGIN_CODE_MINUTES)
    challenge.attempts = 0
    challenge.last_sent_at = _now()
    await _send(db, challenge, user, code)
    return challenge, user


async def verify_code(db: AsyncSession, challenge_id: str, code: str, purpose: str) -> User:
    """Valida el código. Si es correcto, borra el desafío (un solo uso) y retorna el usuario."""
    challenge = await _get(db, challenge_id)
    if challenge is None or challenge.purpose != purpose:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"El código ya no es válido. {RESTART_LOGIN}")

    if challenge.expires_at <= _now():
        await _discard(db, challenge)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"El código venció. {RESTART_LOGIN}")

    if not hmac.compare_digest(challenge.code_hash, hash_code(challenge.id, code)):
        challenge.attempts += 1
        left = settings.LOGIN_CODE_MAX_ATTEMPTS - challenge.attempts
        if left <= 0:
            await _discard(db, challenge)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Demasiados intentos con un código incorrecto. {RESTART_LOGIN}",
            )
        try:
            await db.commit()
        except SQLAlchemyError as exc:
            await db.rollback()
            raise HTTPException(status_code=503, detail="No se pudo validar el código.") from exc
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"El código no es correcto. Te {'queda' if left == 1 else 'quedan'} {left} "
            f"{'intento' if left == 1 else 'intentos'}.",
        )

    user = await db.get(User, challenge.user_id)
    await _discard(db, challenge)
    return user
