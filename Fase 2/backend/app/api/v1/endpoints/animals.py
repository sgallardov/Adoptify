from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from geoalchemy2 import Geography
from geoalchemy2.elements import WKTElement
from sqlalchemy import cast, func, select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.v1.endpoints.auth import get_current_user, get_optional_user
from app.db.database import get_db
from app.models.animal import Animal
from app.models.user import User
from app.schemas.animal import AnimalCreate, AnimalResponse, AnimalUpdate, NearbyAnimalResponse

router = APIRouter()


def _point(latitude: float, longitude: float) -> WKTElement:
    # PostGIS guarda el punto como (longitud, latitud)
    return WKTElement(f"POINT({longitude} {latitude})", srid=4326)


def _require_foundation_staff(current_user: User) -> None:
    """Solo fundaciones (con su fundación asignada) y administradores gestionan animales."""
    if current_user.role == "admin":
        return
    if current_user.role != "foundation" or current_user.foundation_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tu cuenta no puede gestionar animales.",
        )


async def _get_owned_animal(animal_id: int, current_user: User, db: AsyncSession) -> Animal:
    """Busca el animal y comprueba que la cuenta puede gestionarlo (admin: todos; fundación: solo los suyos)."""
    _require_foundation_staff(current_user)
    try:
        animal = (
            await db.execute(
                select(Animal).options(selectinload(Animal.foundation)).where(Animal.id == animal_id)
            )
        ).scalar_one_or_none()
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar el animal.") from exc
    if animal is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Animal no encontrado.")
    if current_user.role != "admin" and animal.foundation_id != current_user.foundation_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Este animal pertenece a otra fundación.",
        )
    return animal


@router.get(
    "",
    response_model=list[AnimalResponse],
    summary="Listar animales publicados",
    description=(
        "Público para visitantes y adoptantes. Si quien consulta es una fundación, "
        "solo ve los animales de su propia fundación."
    ),
)
async def list_animals(
    current_user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
):
    statement = select(Animal).options(selectinload(Animal.foundation)).order_by(Animal.id)
    if current_user is not None and current_user.role == "foundation":
        # Una cuenta de fundación sin fundación asignada no ve ningún animal
        statement = statement.where(Animal.foundation_id == current_user.foundation_id)
    try:
        result = await db.execute(statement)
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


@router.post(
    "",
    response_model=AnimalResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Publicar un animal",
    responses={
        401: {"description": "Se requiere iniciar sesión"},
        403: {"description": "La cuenta no es de fundación o intenta publicar en otra fundación"},
    },
)
async def create_animal(
    payload: AnimalCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_foundation_staff(current_user)
    if current_user.role == "admin":
        if payload.foundation_id is None:
            raise HTTPException(status_code=422, detail="Indica la fundación (foundation_id) del animal.")
        foundation_id = payload.foundation_id
    else:
        if payload.foundation_id not in (None, current_user.foundation_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No puedes publicar animales en otra fundación.",
            )
        foundation_id = current_user.foundation_id

    data = payload.model_dump(exclude={"latitude", "longitude", "foundation_id"})
    animal = Animal(foundation_id=foundation_id, **data)
    if payload.latitude is not None:
        animal.location = _point(payload.latitude, payload.longitude)
    db.add(animal)
    try:
        await db.commit()
    except IntegrityError as exc:
        # Solo ocurre si un admin indica una fundación que no existe
        await db.rollback()
        raise HTTPException(status_code=422, detail="La fundación indicada no existe.") from exc
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar el animal.") from exc
    return await _get_owned_animal(animal.id, current_user, db)


@router.patch(
    "/{animal_id}",
    response_model=AnimalResponse,
    summary="Editar un animal o cambiar su estado",
    responses={
        401: {"description": "Se requiere iniciar sesión"},
        403: {"description": "El animal pertenece a otra fundación"},
        404: {"description": "Animal no encontrado"},
    },
)
async def update_animal(
    animal_id: int,
    payload: AnimalUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    animal = await _get_owned_animal(animal_id, current_user, db)
    for field, value in payload.model_dump(exclude_unset=True, exclude={"latitude", "longitude"}).items():
        setattr(animal, field, value)
    if "latitude" in payload.model_fields_set:
        animal.location = _point(payload.latitude, payload.longitude)
    try:
        await db.commit()
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo actualizar el animal.") from exc
    return await _get_owned_animal(animal_id, current_user, db)


@router.delete(
    "/{animal_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar un animal",
    responses={
        401: {"description": "Se requiere iniciar sesión"},
        403: {"description": "El animal pertenece a otra fundación"},
        404: {"description": "Animal no encontrado"},
    },
)
async def delete_animal(
    animal_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    animal = await _get_owned_animal(animal_id, current_user, db)
    try:
        await db.delete(animal)
        await db.commit()
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo eliminar el animal.") from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
