from fastapi import APIRouter, Depends, HTTPException, Query
from geoalchemy2 import Geography
from sqlalchemy import cast, func, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.database import get_db
from app.models.animal import Animal
from app.schemas.animal import AnimalResponse, NearbyAnimalResponse

router = APIRouter()


@router.get("", response_model=list[AnimalResponse], summary="Listar animales publicados")
async def list_animals(db: AsyncSession = Depends(get_db)):
    try:
        result = await db.execute(
            select(Animal).options(selectinload(Animal.foundation)).order_by(Animal.id)
        )
        return result.scalars().all()
    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=503, detail="No se pudo consultar la lista de animales."
        ) from exc


@router.get(
    "/nearby",
    response_model=list[NearbyAnimalResponse],
    summary="Buscar animales disponibles cerca de un punto",
    description=(
        "Devuelve los animales con estado 'available' que están dentro del radio indicado, "
        "ordenados del más cercano al más lejano. La distancia se calcula con PostGIS sobre "
        "la superficie terrestre (geography), en kilómetros."
    ),
)
async def list_nearby_animals(
    lat: float = Query(..., ge=-90, le=90, description="Latitud del punto de búsqueda"),
    lng: float = Query(..., ge=-180, le=180, description="Longitud del punto de búsqueda"),
    radius_km: float = Query(10, gt=0, le=100, description="Radio de búsqueda en kilómetros (máximo 100)"),
    db: AsyncSession = Depends(get_db),
):
    # Se convierte a geography para medir en metros reales y no en grados
    origin = cast(func.ST_SetSRID(func.ST_MakePoint(lng, lat), 4326), Geography)
    animal_location = cast(Animal.location, Geography)
    distance_m = func.ST_Distance(animal_location, origin).label("distance_m")

    statement = (
        select(Animal, distance_m)
        .options(selectinload(Animal.foundation))
        .where(
            Animal.status == "available",
            Animal.location.is_not(None),
            func.ST_DWithin(animal_location, origin, radius_km * 1000),
        )
        .order_by(distance_m, Animal.id)
    )
    try:
        rows = (await db.execute(statement)).all()
    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=503, detail="No se pudo buscar animales cercanos."
        ) from exc

    return [
        NearbyAnimalResponse(
            **AnimalResponse.model_validate(animal).model_dump(),
            distance_km=round(distance / 1000, 2),
        )
        for animal, distance in rows
    ]
