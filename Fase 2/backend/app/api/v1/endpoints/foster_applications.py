from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.auth import get_current_user
from app.db.database import get_db
from app.models.foster_application import FosterApplication
from app.models.user import User
from app.schemas.foster_application import FosterApplicationIn, FosterApplicationOut

router = APIRouter()


def _require_adopter(user: User) -> None:
    if user.role != "adopter":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Solo las cuentas de adoptante pueden postular como hogar temporal."
        )


async def _own_application(db: AsyncSession, user: User) -> FosterApplication | None:
    try:
        return (
            await db.execute(select(FosterApplication).where(FosterApplication.user_id == user.id))
        ).scalar_one_or_none()
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar tu postulación.") from exc


@router.get(
    "/me",
    response_model=FosterApplicationOut | None,
    summary="Mi postulación a hogar temporal",
    description="Retorna null si la persona todavía no postula.",
    responses={401: {"description": "Token ausente, inválido o expirado"}},
)
async def get_my_application(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await _own_application(db, current_user)


@router.post(
    "",
    response_model=FosterApplicationOut,
    status_code=status.HTTP_201_CREATED,
    summary="Postular como hogar temporal",
    description=(
        "La postulación es general (no se elige fundación) y cada cuenta tiene una sola. Todos los campos son "
        "obligatorios; nombre y correo se toman de la cuenta. La dirección solo la ven las fundaciones."
    ),
    responses={
        403: {"description": "La cuenta no es de adoptante"},
        409: {"description": "Ya existe una postulación de esta cuenta"},
    },
)
async def create_application(
    payload: FosterApplicationIn,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_adopter(current_user)
    if await _own_application(db, current_user) is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya tienes una postulación. Puedes editarla.")
    application = FosterApplication(user_id=current_user.id, **payload.model_dump())
    db.add(application)
    try:
        await db.commit()
    except IntegrityError as exc:
        # Otra postulación de la misma cuenta se guardó entre la consulta y el commit
        await db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya tienes una postulación. Puedes editarla.") from exc
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar tu postulación.") from exc
    await db.refresh(application)
    return application


@router.put(
    "/me",
    response_model=FosterApplicationOut,
    summary="Editar mi postulación",
    description="Solo mientras está pendiente: una postulación ya revisada por una fundación no se edita.",
    responses={
        404: {"description": "Todavía no postula"},
        409: {"description": "La postulación ya fue revisada"},
    },
)
async def update_my_application(
    payload: FosterApplicationIn,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_adopter(current_user)
    application = await _own_application(db, current_user)
    if application is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Todavía no tienes una postulación.")
    if application.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Tu postulación ya fue revisada por una fundación y no se puede editar. Puedes retirarla.",
        )
    for field, value in payload.model_dump().items():
        setattr(application, field, value)
    try:
        await db.commit()
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo actualizar tu postulación.") from exc
    await db.refresh(application)
    return application


@router.delete(
    "/me",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Retirar mi postulación",
    responses={404: {"description": "Todavía no postula"}},
)
async def withdraw_my_application(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    application = await _own_application(db, current_user)
    if application is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Todavía no tienes una postulación.")
    try:
        await db.delete(application)
        await db.commit()
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo retirar tu postulación.") from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
