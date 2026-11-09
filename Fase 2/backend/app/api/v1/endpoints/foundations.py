from fastapi import APIRouter, Depends, HTTPException, Query
from geoalchemy2 import Geography
from geoalchemy2.shape import to_shape
from sqlalchemy import cast, func, literal, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.database import get_db
from app.models.animal import Animal
from app.models.foundation import Foundation
from app.schemas.animal import PublicAnimalResponse
from app.schemas.foundation import FoundationResponse

router = APIRouter()


def _foundation_response(foundation: Foundation, distance_m: float | None = None) -> FoundationResponse:
    point = to_shape(foundation.location) if foundation.location is not None else None
    available = sorted((a for a in foundation.animals if a.status == "available"), key=lambda a: a.id)
    return FoundationResponse(
        id=foundation.id,
        name=foundation.name,
        description=foundation.description,
        address=foundation.address,
        commune=foundation.commune,
        city=foundation.city,
        phone=foundation.phone,
        email=foundation.email,
        is_verified=foundation.is_verified,
        latitude=point.y if point else None,
        longitude=point.x if point else None,
        distance_km=round(distance_m / 1000, 1) if distance_m is not None else None,
        animals=[PublicAnimalResponse.model_validate(animal) for animal in available],
    )


@router.get(
    "",
    response_model=list[FoundationResponse],
    summary="Listar fundaciones con sus animales en adopción",
    description=(
        "Público. Devuelve las fundaciones con sus datos de contacto y solo los animales disponibles "
        "(status 'available'). Sin `lat`/`lng` se ordenan por nombre; con ambos, de la más cercana a la "
        "más lejana (PostGIS sobre geography) con `distance_km`, y las que no tienen ubicación van al final."
    ),
    responses={422: {"description": "Se envió solo lat o solo lng"}},
)
async def list_foundations(
    lat: float | None = Query(None, ge=-90, le=90, description="Latitud de quien busca (opcional, junto con lng)"),
    lng: float | None = Query(None, ge=-180, le=180, description="Longitud de quien busca (opcional, junto con lat)"),
    db: AsyncSession = Depends(get_db),
):
    if (lat is None) != (lng is None):
        raise HTTPException(status_code=422, detail="Para ordenar por cercanía envía lat y lng juntos.")

    # foundation_name de cada animal necesita la relación inversa cargada
    options = selectinload(Foundation.animals).selectinload(Animal.foundation)
    if lat is None:
        statement = select(Foundation, literal(None).label("distance_m")).options(options).order_by(Foundation.name)
    else:
        # Se convierte a geography para medir en metros reales y no en grados
        origin = cast(func.ST_SetSRID(func.ST_MakePoint(lng, lat), 4326), Geography)
        distance_m = func.ST_Distance(cast(Foundation.location, Geography), origin).label("distance_m")
        statement = (
            select(Foundation, distance_m)
            .options(options)
            .order_by(distance_m.asc().nulls_last(), Foundation.name)
        )
    try:
        result = await db.execute(statement)
        return [_foundation_response(foundation, distance) for foundation, distance in result.all()]
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar las fundaciones.") from exc
