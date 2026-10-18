from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.models.animal import Animal
from app.schemas.animal import AnimalResponse

router = APIRouter()


@router.get("", response_model=list[AnimalResponse], summary="Listar animales publicados")
async def list_animals(db: AsyncSession = Depends(get_db)):
    try:
        result = await db.execute(select(Animal).order_by(Animal.id))
        return result.scalars().all()
    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=503, detail="No se pudo consultar la lista de animales."
        ) from exc
