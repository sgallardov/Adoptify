from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from geoalchemy2 import Geography
from geoalchemy2.elements import WKTElement
from geoalchemy2.shape import to_shape
from sqlalchemy import case, cast, func, select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.v1.endpoints.auth import get_current_user
from app.db.database import get_db
from app.models.foster_application import FosterApplication
from app.models.foundation import Foundation
from app.models.user import User
from app.schemas.foster_application import (
    FosterApplicationForFoundation,
    FosterApplicationIn,
    FosterApplicationOut,
    FosterDecision,
    FosterStatus,
)

router = APIRouter()

# HU-AA: una fundación solo ve (y decide) las postulaciones de hogares a este radio o menos de su sede
FOSTER_RADIUS_KM = 10


def _location(latitude: float, longitude: float) -> WKTElement:
    # PostGIS guarda el punto como (longitud, latitud)
    return WKTElement(f"POINT({longitude} {latitude})", srid=4326)


def _own(application: FosterApplication) -> FosterApplicationOut:
    """La postulación vista por su dueño: la ubicación se publica como latitud y longitud."""
    out = FosterApplicationOut.model_validate(application)
    if application.location is not None:
        point = to_shape(application.location)
        out.latitude, out.longitude = point.y, point.x
    return out


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
    application = await _own_application(db, current_user)
    return _own(application) if application is not None else None


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
    application = FosterApplication(
        user_id=current_user.id,
        **payload.model_dump(exclude={"latitude", "longitude"}),
        location=_location(payload.latitude, payload.longitude),
    )
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
    return _own(application)


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
    for field, value in payload.model_dump(exclude={"latitude", "longitude"}).items():
        setattr(application, field, value)
    application.location = _location(payload.latitude, payload.longitude)
    try:
        await db.commit()
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo actualizar tu postulación.") from exc
    await db.refresh(application)
    return _own(application)


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


def _for_foundation(application: FosterApplication, user: User, distance_m: float) -> FosterApplicationForFoundation:
    decided_by = application.decided_by_foundation
    return FosterApplicationForFoundation(
        id=application.id,
        user_id=application.user_id,
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
        distance_km=round(distance_m / 1000, 1),
        status=application.status,
        decided_by_foundation_name=decided_by.name if decided_by is not None else None,
        decided_at=application.decided_at,
        can_decide=application.status == "pending" or application.decided_by_foundation_id == user.foundation_id,
        created_at=application.created_at,
    )


def _with_relations():
    return selectinload(FosterApplication.user), selectinload(FosterApplication.decided_by_foundation)


def _distance_to_foundation(foundation_id: int):
    """Distancia en metros (geography) del hogar a la sede de la fundación; nula si falta alguna ubicación."""
    sede = (
        select(cast(Foundation.location, Geography)).where(Foundation.id == foundation_id).scalar_subquery()
    )
    return func.ST_Distance(cast(FosterApplication.location, Geography), sede)


async def _require_foundation_location(db: AsyncSession, user: User) -> None:
    try:
        location = (
            await db.execute(select(Foundation.location).where(Foundation.id == user.foundation_id))
        ).scalar_one_or_none()
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar tu fundación.") from exc
    if location is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Tu fundación no tiene ubicación registrada. Complétala para ver las postulaciones cercanas.",
        )


@router.get(
    "",
    response_model=list[FosterApplicationForFoundation],
    summary="Postulaciones a hogar temporal cercanas (fundaciones)",
    description=(
        f"Solo cuentas de fundación vinculadas. Solo aparecen las postulaciones cuyo hogar está a {FOSTER_RADIUS_KM} km "
        "o menos de la sede de la fundación (y las que no tienen ubicación no aparecen). Incluye el contacto completo "
        "del postulante (nombre, correo, teléfono y dirección). Primero las pendientes y, dentro de cada estado, de "
        "la más antigua a la más nueva. `status` filtra por estado."
    ),
    responses={
        403: {"description": "La cuenta no es de fundación (un adoptante no ve postulaciones)"},
        409: {"description": "La fundación todavía no tiene ubicación registrada"},
    },
)
async def list_applications(
    status_filter: FosterStatus | None = Query(None, alias="status", description="pending, approved o rejected"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_foundation(current_user)
    await _require_foundation_location(db, current_user)
    pending_first = case((FosterApplication.status == "pending", 0), else_=1)
    distance_m = _distance_to_foundation(current_user.foundation_id).label("distance_m")
    statement = (
        select(FosterApplication, distance_m)
        .options(*_with_relations())
        .where(distance_m <= FOSTER_RADIUS_KM * 1000)
        .order_by(pending_first, FosterApplication.created_at)
    )
    if status_filter is not None:
        statement = statement.where(FosterApplication.status == status_filter)
    try:
        rows = (await db.execute(statement)).all()
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar las postulaciones.") from exc
    return [_for_foundation(application, current_user, distance) for application, distance in rows]


@router.patch(
    "/{application_id}",
    response_model=FosterApplicationForFoundation,
    summary="Aprobar o rechazar una postulación",
    description=(
        "El estado es global: lo ven todas las fundaciones y queda registrado quién decidió. Una postulación "
        "pendiente la decide cualquier fundación cercana; ya decidida, solo la fundación que decidió puede cambiarla "
        f"o volverla a `pending`. Una fundación solo decide postulaciones a {FOSTER_RADIUS_KM} km o menos de su sede."
    ),
    responses={
        403: {"description": "La cuenta no es de fundación, la decidió otra fundación o el hogar está fuera del radio"},
        404: {"description": "Postulación no encontrada (por ejemplo, la retiraron)"},
        409: {"description": "La fundación todavía no tiene ubicación registrada"},
    },
)
async def decide_application(
    application_id: int,
    payload: FosterDecision,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_foundation(current_user)
    await _require_foundation_location(db, current_user)
    distance_m = _distance_to_foundation(current_user.foundation_id).label("distance_m")
    statement = (
        select(FosterApplication, distance_m)
        .options(*_with_relations())
        .where(FosterApplication.id == application_id)
        .execution_options(populate_existing=True)
    )
    try:
        row = (await db.execute(statement)).one_or_none()
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar la postulación.") from exc
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="La postulación ya no existe; quizá la retiraron.")
    application, distance = row
    if distance is None or distance > FOSTER_RADIUS_KM * 1000:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Esta postulación está a más de {FOSTER_RADIUS_KM} km de tu fundación.",
        )
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
        application = (await db.execute(statement)).one()[0]
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar la decisión.") from exc
    return _for_foundation(application, current_user, distance)
