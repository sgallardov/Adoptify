from fastapi import APIRouter, Depends, status, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, decode_access_token, hash_password, verify_password
from app.db.database import get_db
from app.models.user import User
from app.schemas.user import LoginRequest, TokenResponse, UserCreate, UserPublic

router = APIRouter()
bearer_scheme = HTTPBearer()

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

    existing = await db.execute(select(User).where(User.rut == payload.rut))
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
    response_model=TokenResponse,
    summary="Iniciar sesión con correo y contraseña",
    responses={
        401: {"description": "Correo o contraseña incorrectos"},
        403: {"description": "La cuenta no corresponde al tipo elegido (usuario o fundación)"},
    },
)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    # Mismo mensaje para correo inexistente y contraseña errónea, para no revelar qué correos existen
    if user is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Correo o contraseña incorrectos")

    if user.role not in ACCOUNT_TYPE_ROLES[payload.account_type]:
        other_tab = "Usuario" if payload.account_type == "foundation" else "Fundación"
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Esta cuenta no es de este tipo. Inicia sesión en la pestaña {other_tab}.",
        )

    return TokenResponse(access_token=create_access_token(user.email), role=user.role)


@router.get(
    "/me",
    response_model=UserPublic,
    summary="Obtener el usuario de la sesión actual",
    responses={401: {"description": "Token ausente, inválido o expirado"}},
)
async def me(current_user: User = Depends(get_current_user)):
    return current_user
