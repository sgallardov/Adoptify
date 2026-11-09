from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.models.veterinary_clinic import VeterinaryClinic
from app.schemas.veterinary_clinic import VeterinaryClinicResponse

router = APIRouter()


@router.get(
    "",
    response_model=list[VeterinaryClinicResponse],
    summary="Listar clínicas veterinarias para emergencias",
    description=(
        "Público. Todas las clínicas veterinarias cargadas (datos de OpenStreetMap, © colaboradores de "
        "OpenStreetMap, licencia ODbL), primero las de urgencias o 24 horas y luego por nombre. La app las "
        "muestra como pines fijos con una cruz roja."
    ),
)
async def list_veterinary_clinics(db: AsyncSession = Depends(get_db)):
    statement = select(VeterinaryClinic).order_by(VeterinaryClinic.emergency.desc(), VeterinaryClinic.name)
    try:
        return (await db.execute(statement)).scalars().all()
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar las clínicas veterinarias.") from exc
