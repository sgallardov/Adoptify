from fastapi import APIRouter, Depends, HTTPException, Query, status
from geoalchemy2 import Geography
from geoalchemy2.elements import WKTElement
from sqlalchemy import cast, func, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.auth import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.models.veterinary_clinic import VeterinaryClinic
from app.schemas.veterinary_clinic import (
    VeterinaryClinicCreate,
    VeterinaryClinicResponse,
    VeterinaryClinicUpdate,
)

router = APIRouter()


def _point(latitude: float, longitude: float) -> WKTElement:
    """PostGIS recibe POINT(longitud latitud), no el orden visual habitual."""
    return WKTElement(f"POINT({longitude} {latitude})", srid=4326)


def _require_admin(current_user: User) -> None:
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo administración puede gestionar veterinarias.")


@router.get(
    "",
    response_model=list[VeterinaryClinicResponse],
    summary="Buscar veterinarias activas cercanas",
    description=(
        "Público. Con latitud y longitud devuelve solo veterinarias activas dentro del radio, ordenadas "
        "por distancia. Sin coordenadas conserva el listado general para clientes antiguos. "
        "Los datos importados son © colaboradores de OpenStreetMap, licencia ODbL."
    ),
)
async def list_veterinary_clinics(
    lat: float | None = Query(None, ge=-90, le=90, description="Latitud del punto de búsqueda"),
    lng: float | None = Query(None, ge=-180, le=180, description="Longitud del punto de búsqueda"),
    radius_km: float = Query(10, gt=0, le=100, description="Radio de búsqueda en kilómetros (máximo 100)"),
    db: AsyncSession = Depends(get_db),
):
    if (lat is None) != (lng is None):
        raise HTTPException(status_code=422, detail="Debes indicar lat y lng juntos.")

    statement = select(VeterinaryClinic).where(VeterinaryClinic.is_active.is_(True))
    if lat is None:
        statement = statement.order_by(VeterinaryClinic.emergency.desc(), VeterinaryClinic.name)
    else:
        origin = cast(func.ST_SetSRID(func.ST_MakePoint(lng, lat), 4326), Geography)
        clinic_location = cast(VeterinaryClinic.location, Geography)
        distance_m = func.ST_Distance(clinic_location, origin).label("distance_m")
        statement = statement.where(func.ST_DWithin(clinic_location, origin, radius_km * 1000)).order_by(distance_m, VeterinaryClinic.id)
    try:
        return (await db.execute(statement)).scalars().all()
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar las veterinarias.") from exc


@router.post("", response_model=VeterinaryClinicResponse, status_code=status.HTTP_201_CREATED)
async def create_veterinary_clinic(
    payload: VeterinaryClinicCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_admin(current_user)
    data = payload.model_dump(exclude={"latitude", "longitude"})
    clinic = VeterinaryClinic(**data, location=_point(payload.latitude, payload.longitude))
    db.add(clinic)
    try:
        await db.commit()
        await db.refresh(clinic)
        return clinic
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar la veterinaria.") from exc


@router.patch("/{clinic_id}", response_model=VeterinaryClinicResponse)
async def update_veterinary_clinic(
    clinic_id: int,
    payload: VeterinaryClinicUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_admin(current_user)
    try:
        clinic = await db.get(VeterinaryClinic, clinic_id)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar la veterinaria.") from exc
    if clinic is None:
        raise HTTPException(status_code=404, detail="Veterinaria no encontrada.")
    for field, value in payload.model_dump(exclude_unset=True, exclude={"latitude", "longitude"}).items():
        setattr(clinic, field, value)
    if "latitude" in payload.model_fields_set:
        clinic.location = _point(payload.latitude, payload.longitude)
    try:
        await db.commit()
        await db.refresh(clinic)
        return clinic
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo actualizar la veterinaria.") from exc
