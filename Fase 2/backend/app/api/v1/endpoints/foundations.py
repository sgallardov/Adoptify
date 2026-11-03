from fastapi import APIRouter, Depends, HTTPException
from geoalchemy2.shape import to_shape
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.database import get_db
from app.models.animal import Animal
from app.models.foundation import Foundation
from app.schemas.animal import PublicAnimalResponse
from app.schemas.foundation import FoundationResponse

router = APIRouter()


def _foundation_response(foundation: Foundation) -> FoundationResponse:
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
        animals=[PublicAnimalResponse.model_validate(animal) for animal in available],
    )


@router.get(
    "",
    response_model=list[FoundationResponse],
    summary="Listar fundaciones con sus animales en adopción",
    description=(
        "Público. Devuelve las fundaciones ordenadas por nombre, con sus datos de contacto "
        "y solo los animales disponibles (status 'available')."
    ),
)
async def list_foundations(db: AsyncSession = Depends(get_db)):
    # foundation_name de cada animal necesita la relación inversa cargada
    statement = (
        select(Foundation)
        .options(selectinload(Foundation.animals).selectinload(Animal.foundation))
        .order_by(Foundation.name)
    )
    try:
        result = await db.execute(statement)
        return [_foundation_response(foundation) for foundation in result.scalars().all()]
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar las fundaciones.") from exc
