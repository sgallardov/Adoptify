from fastapi import APIRouter, Depends, Response, status, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.rut_crypto import hash_rut
from app.core.security import create_access_token, decode_access_token, hash_password, verify_password
from app.db.database import get_db
from app.models.login_challenge import LoginChallenge
from app.models.user import User
from app.schemas.user import (
    ChallengeResponse,
    LoginRequest,
    ResendCodeRequest,
    TokenResponse,
    TwoFactorDisableRequest,
    UserCreate,
    UserPublic,
    VerifyCodeRequest,
)
from app.services import two_factor

router = APIRouter()
bearer_scheme = HTTPBearer()
optional_bearer_scheme = HTTPBearer(auto_error=False)

# Roles que puede tener una cuenta para entrar por cada pestaña del login
ACCOUNT_TYPE_ROLES = {
    "user": {"adopter"},
    "foundation": {"foundation", "admin"},
}


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    Dependencia que identifica al usuario a partir del token Bearer.
    Retorna 401 si el token falta, es inválido, expiró o el usuario ya no existe.
    """
    email = decode_access_token(credentials.credentials)
    if email is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido o expirado")

    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido o expirado")
    return user


async def get_optional_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(optional_bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User | None:
    """
    Igual que get_current_user, pero para rutas públicas que cambian según quién consulta.
    Sin token, o con un token inválido, retorna None y se trata como visitante.
    """
    if credentials is None:
        return None
    email = decode_access_token(credentials.credentials)
    if email is None:
        return None
    result = await db.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none()


@router.post(
    "/register",
    response_model=UserPublic,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar un usuario con correo y contraseña",
    responses={409: {"description": "Ya existe un usuario con ese correo o RUT"}},
)
async def register(payload: UserCreate, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(select(User).where(User.email == payload.email))
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya existe un usuario con ese correo")

    existing = await db.execute(select(User).where(User.rut_hash == hash_rut(payload.rut)))
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya existe un usuario con ese RUT")

    user = User(
        email=payload.email,
        rut=payload.rut,
        hashed_password=hash_password(payload.password),
        full_name=payload.full_name,
        role="adopter",
        preferences={},
    )
    db.add(user)
    try:
        await db.commit()
    except IntegrityError:
        # Otro registro con el mismo correo o RUT se guardó entre la consulta y el commit
        await db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya existe un usuario con ese correo o RUT")
    await db.refresh(user)
    return user


@router.post(
    "/login",
    response_model=TokenResponse | ChallengeResponse,
    summary="Iniciar sesión con correo y contraseña",
    description=(
        "Sin verificación en dos pasos, responde 200 con el token. Con ella activa, valida la contraseña, "
        "envía un código de 6 dígitos al correo y responde **202** con `challenge_id`, sin token: el token "
        "se obtiene con POST /auth/verify-code."
    ),
    responses={
        202: {"description": "Código enviado al correo (verificación en dos pasos activa)", "model": ChallengeResponse},
        401: {"description": "Correo o contraseña incorrectos"},
        403: {"description": "La cuenta no corresponde al tipo elegido (usuario o fundación)"},
        503: {"description": "No se pudo enviar el código por correo"},
    },
)
async def login(payload: LoginRequest, response: Response, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    # Mismo mensaje para correo inexistente y contraseña errónea, para no revelar qué correos existen
    if user is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Correo o contraseña incorrectos")

    if payload.account_type and user.role not in ACCOUNT_TYPE_ROLES[payload.account_type]:
        other_tab = "Usuario" if payload.account_type == "foundation" else "Fundación"
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Esta cuenta no es de este tipo. Inicia sesión en la pestaña {other_tab}.",
        )

    # Verificación en dos pasos (HU-I): la contraseña sola no entrega token
    if user.two_factor_enabled:
        challenge = await two_factor.start_challenge(db, user, "login")
        response.status_code = status.HTTP_202_ACCEPTED
        return ChallengeResponse(**two_factor.challenge_info(challenge, user.email))

    return TokenResponse(access_token=create_access_token(user.email), role=user.role)


@router.post(
    "/verify-code",
    response_model=TokenResponse,
    summary="Ingresar el código del correo y obtener el token",
    description=(
        f"Segundo paso del login con verificación en dos pasos. El código vence a los "
        f"{settings.LOGIN_CODE_MINUTES} minutos y tras {settings.LOGIN_CODE_MAX_ATTEMPTS} intentos fallidos "
        "hay que volver a iniciar sesión."
    ),
    responses={401: {"description": "Código incorrecto, vencido o agotado: el detalle dice qué hacer"}},
)
async def verify_login_code(payload: VerifyCodeRequest, db: AsyncSession = Depends(get_db)):
    user = await two_factor.verify_code(db, payload.challenge_id, payload.code, "login")
    return TokenResponse(access_token=create_access_token(user.email), role=user.role)


@router.post(
    "/resend-code",
    response_model=ChallengeResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Reenviar el código de verificación",
    description=(
        f"Envía un código nuevo para el mismo desafío (el anterior deja de servir), como máximo uno cada "
        f"{settings.LOGIN_CODE_RESEND_SECONDS} segundos. Sirve para el login y para activar la verificación."
    ),
    responses={
        401: {"description": "El desafío venció o ya no existe: hay que empezar de nuevo"},
        429: {"description": "Todavía no se puede pedir otro código"},
    },
)
async def resend_code(payload: ResendCodeRequest, db: AsyncSession = Depends(get_db)):
    challenge, user = await two_factor.resend_code(db, payload.challenge_id)
    return ChallengeResponse(**two_factor.challenge_info(challenge, user.email))


@router.post(
    "/two-factor/enable",
    response_model=ChallengeResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Empezar a activar la verificación en dos pasos",
    description=(
        "Envía un código al correo de la cuenta. La verificación queda activa solo al confirmarlo con "
        "POST /auth/two-factor/confirm, así nadie se bloquea con un correo que no recibe."
    ),
    responses={409: {"description": "Ya está activa"}},
)
async def start_two_factor(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if current_user.two_factor_enabled:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="La verificación en dos pasos ya está activa.")
    challenge = await two_factor.start_challenge(db, current_user, "enable")
    return ChallengeResponse(**two_factor.challenge_info(challenge, current_user.email))


@router.post(
    "/two-factor/confirm",
    response_model=UserPublic,
    summary="Confirmar el código y activar la verificación en dos pasos",
    description=(
        "Los errores del código responden **400**, no 401: con la sesión iniciada, la app y el portal "
        "cierran sesión ante un 401, y equivocarse en el código no debe sacar a nadie de su cuenta."
    ),
    responses={400: {"description": "Código incorrecto, vencido o de otra cuenta"}},
)
async def confirm_two_factor(
    payload: VerifyCodeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # El desafío debe ser de esta misma cuenta: no se puede activar con el código de otra persona
    challenge = await db.get(LoginChallenge, payload.challenge_id)
    if challenge is None or challenge.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="El código ya no es válido. Pide uno nuevo.")
    try:
        await two_factor.verify_code(db, payload.challenge_id, payload.code, "enable")
    except HTTPException as exc:
        if exc.status_code != status.HTTP_401_UNAUTHORIZED:
            raise
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.detail) from exc
    return await _set_two_factor(db, current_user, True)


@router.post(
    "/two-factor/disable",
    response_model=UserPublic,
    summary="Desactivar la verificación en dos pasos",
    responses={400: {"description": "Contraseña incorrecta (400 y no 401, para no cerrar la sesión)"}},
)
async def disable_two_factor(
    payload: TwoFactorDisableRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not verify_password(payload.password, current_user.hashed_password):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="La contraseña no es correcta.")
    return await _set_two_factor(db, current_user, False)


async def _set_two_factor(db: AsyncSession, user: User, enabled: bool) -> User:
    user.two_factor_enabled = enabled
    try:
        await db.commit()
        await db.refresh(user)
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar la verificación en dos pasos.") from exc
    return user


@router.get(
    "/me",
    response_model=UserPublic,
    summary="Obtener el usuario de la sesión actual",
    responses={401: {"description": "Token ausente, inválido o expirado"}},
)
async def me(current_user: User = Depends(get_current_user)):
    return current_user
