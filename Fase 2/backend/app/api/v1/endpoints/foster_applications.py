from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import case, func, select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.v1.endpoints.auth import get_current_user
from app.db.database import get_db
from app.models.foster_application import FosterApplication
from app.models.user import User
from app.schemas.foster_application import (
    FosterApplicationForFoundation,
    FosterApplicationIn,
    FosterApplicationOut,
    FosterDecision,
    FosterStatus,
)

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


# --- Vista de las fundaciones (portal) ---

def _require_foundation(user: User) -> None:
    if user.role != "foundation" or user.foundation_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Solo una fundación vinculada puede ver las postulaciones."
        )


def _for_foundation(application: FosterApplication, user: User) -> FosterApplicationForFoundation:
    decided_by = application.decided_by_foundation
    return FosterApplicationForFoundation(
        id=application.id,
        full_name=application.user.full_name,
        email=application.user.email,
        phone=application.phone,
        address=application.address,
        species=application.species,
        sizes=application.sizes,
        space=application.space,
        max_animals=application.max_animals,
        max_days=application.max_days,
        availability=application.availability,
        status=application.status,
        decided_by_foundation_name=decided_by.name if decided_by is not None else None,
        decided_at=application.decided_at,
        can_decide=application.status == "pending" or application.decided_by_foundation_id == user.foundation_id,
        created_at=application.created_at,
    )


def _with_relations():
    return selectinload(FosterApplication.user), selectinload(FosterApplication.decided_by_foundation)


@router.get(
    "",
    response_model=list[FosterApplicationForFoundation],
    summary="Postulaciones a hogar temporal (fundaciones)",
    description=(
        "Solo cuentas de fundación vinculadas: incluye el contacto completo del postulante (nombre, correo, "
        "teléfono y dirección). Primero las pendientes y, dentro de cada estado, de la más antigua a la más nueva. "
        "`status` filtra por estado."
    ),
    responses={403: {"description": "La cuenta no es de fundación (un adoptante no ve postulaciones)"}},
)
async def list_applications(
    status_filter: FosterStatus | None = Query(None, alias="status", description="pending, approved o rejected"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_foundation(current_user)
    pending_first = case((FosterApplication.status == "pending", 0), else_=1)
    statement = select(FosterApplication).options(*_with_relations()).order_by(pending_first, FosterApplication.created_at)
    if status_filter is not None:
        statement = statement.where(FosterApplication.status == status_filter)
    try:
        applications = (await db.execute(statement)).scalars().all()
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar las postulaciones.") from exc
    return [_for_foundation(application, current_user) for application in applications]


@router.patch(
    "/{application_id}",
    response_model=FosterApplicationForFoundation,
    summary="Aprobar o rechazar una postulación",
    description=(
        "El estado es global: lo ven todas las fundaciones y queda registrado quién decidió. Una postulación "
        "pendiente la decide cualquier fundación; ya decidida, solo la fundación que decidió puede cambiarla o "
        "volverla a `pending`."
    ),
    responses={
        403: {"description": "La cuenta no es de fundación, o la decidió otra fundación"},
        404: {"description": "Postulación no encontrada (por ejemplo, la retiraron)"},
    },
)
async def decide_application(
    application_id: int,
    payload: FosterDecision,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_foundation(current_user)
    statement = (
        select(FosterApplication)
        .options(*_with_relations())
        .where(FosterApplication.id == application_id)
        .execution_options(populate_existing=True)
    )
    try:
        application = (await db.execute(statement)).scalar_one_or_none()
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar la postulación.") from exc
    if application is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="La postulación ya no existe; quizá la retiraron.")
    if application.status != "pending" and application.decided_by_foundation_id != current_user.foundation_id:
        other = application.decided_by_foundation.name if application.decided_by_foundation else "otra fundación"
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=f"Esta postulación ya la revisó {other}.")

    application.status = payload.status
    if payload.status == "pending":
        application.decided_by_foundation_id = None
        application.decided_at = None
    else:
        application.decided_by_foundation_id = current_user.foundation_id
        application.decided_at = func.now()
    try:
        await db.commit()
        application = (await db.execute(statement)).scalar_one()
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar la decisión.") from exc
    return _for_foundation(application, current_user)
