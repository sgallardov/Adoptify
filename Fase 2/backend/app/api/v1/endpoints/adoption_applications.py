from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.auth import get_current_user
from app.db.database import get_db
from app.models.adoption_application import AdoptionApplication
from app.models.animal import Animal
from app.models.foundation import Foundation
from app.models.user import User
from app.schemas.adoption_application import (
    AdoptionApplicationCreate,
    ApplicationStatusUpdate,
    ApplicantSummary,
    FoundationApplicationResponse,
    MyApplicationResponse,
)

router = APIRouter()


def _require_foundation(user: User) -> None:
    if user.role != "foundation" or user.foundation_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo una fundación puede revisar postulaciones.")


def _foundation_response(application: AdoptionApplication, animal: Animal, adopter: User) -> FoundationApplicationResponse:
    return FoundationApplicationResponse(
        id=application.id,
        animal_id=animal.id,
        animal_name=animal.name,
        status=application.status,
        applicant=ApplicantSummary(user_id=adopter.id, full_name=adopter.full_name),
        profile=application.profile_snapshot,
        message=application.message,
        created_at=application.created_at,
    )


def _my_response(application: AdoptionApplication, animal: Animal, foundation: Foundation) -> MyApplicationResponse:
    return MyApplicationResponse(
        id=application.id, animal_id=animal.id, animal_name=animal.name, animal_photo_url=animal.photo_url,
        foundation_name=foundation.name, status=application.status, created_at=application.created_at,
    )


@router.post("/animals/{animal_id}", response_model=MyApplicationResponse, status_code=status.HTTP_201_CREATED)
async def create_application(
    animal_id: int,
    payload: AdoptionApplicationCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "adopter":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo las cuentas adoptantes pueden postular.")
    animal = await db.get(Animal, animal_id)
    if animal is None:
        raise HTTPException(status_code=404, detail="Animal no encontrado.")
    if animal.status != "available":
        raise HTTPException(status_code=409, detail="Este animal ya no recibe postulaciones.")
    foundation = await db.get(Foundation, animal.foundation_id)
    if foundation is None:
        raise HTTPException(status_code=409, detail="La fundación del animal no está disponible.")
    application = (await db.execute(
        select(AdoptionApplication).where(
            AdoptionApplication.animal_id == animal.id, AdoptionApplication.adopter_id == current_user.id
        )
    )).scalar_one_or_none()
    if application is None:
        application = AdoptionApplication(
            animal_id=animal.id,
            foundation_id=animal.foundation_id,
            adopter_id=current_user.id,
            profile_snapshot=payload.profile.model_dump(),
            message=payload.message,
        )
        db.add(application)
    elif application.status == "withdrawn":
        # Quien retiró su postulación puede volver a postular: la fila se reutiliza (hay una sola por animal y persona)
        application.status = "submitted"
        application.profile_snapshot = payload.profile.model_dump()
        application.message = payload.message
        application.created_at = func.now()
    else:
        raise HTTPException(status_code=409, detail="Ya enviaste una postulación para este animal.")
    try:
        await db.commit()
        await db.refresh(application)
    except IntegrityError as exc:
        await db.rollback()
        raise HTTPException(status_code=409, detail="Ya enviaste una postulación para este animal.") from exc
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo enviar la postulación.") from exc
    return _my_response(application, animal, foundation)


@router.get("/mine", response_model=list[MyApplicationResponse])
async def my_applications(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if current_user.role != "adopter":
        raise HTTPException(status_code=403, detail="Solo las cuentas adoptantes tienen postulaciones.")
    rows = (await db.execute(
        select(AdoptionApplication, Animal, Foundation)
        .join(Animal, Animal.id == AdoptionApplication.animal_id)
        .join(Foundation, Foundation.id == AdoptionApplication.foundation_id)
        .where(AdoptionApplication.adopter_id == current_user.id, AdoptionApplication.status != "withdrawn")
        .order_by(AdoptionApplication.created_at.desc())
    )).all()
    return [_my_response(item, animal, foundation) for item, animal, foundation in rows]


@router.delete("/{application_id}", status_code=status.HTTP_204_NO_CONTENT)
async def withdraw_application(application_id: int, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    application = await db.get(AdoptionApplication, application_id)
    # Una ajena responde igual que una inexistente: no se revela que existe
    if application is None or current_user.role != "adopter" or application.adopter_id != current_user.id             or application.status == "withdrawn":
        raise HTTPException(status_code=404, detail="Postulación no encontrada.")
    if application.status == "approved":
        raise HTTPException(status_code=409, detail="Una postulación aprobada no se puede retirar. Contacta a la fundación.")
    application.status = "withdrawn"
    try:
        await db.commit()
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo retirar la postulación.") from exc


@router.get("/foundation", response_model=list[FoundationApplicationResponse])
async def foundation_applications(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    _require_foundation(current_user)
    rows = (await db.execute(
        select(AdoptionApplication, Animal, User)
        .join(Animal, Animal.id == AdoptionApplication.animal_id)
        .join(User, User.id == AdoptionApplication.adopter_id)
        .where(AdoptionApplication.foundation_id == current_user.foundation_id, AdoptionApplication.status != "withdrawn")
        .order_by(AdoptionApplication.created_at.desc())
    )).all()
    return [_foundation_response(application, animal, adopter) for application, animal, adopter in rows]


@router.patch("/{application_id}/status", response_model=FoundationApplicationResponse)
async def update_application_status(
    application_id: int,
    payload: ApplicationStatusUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_foundation(current_user)
    row = (await db.execute(
        select(AdoptionApplication, Animal, User)
        .join(Animal, Animal.id == AdoptionApplication.animal_id)
        .join(User, User.id == AdoptionApplication.adopter_id)
        .where(AdoptionApplication.id == application_id)
    )).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Postulación no encontrada.")
    application, animal, adopter = row
    if application.foundation_id != current_user.foundation_id:
        raise HTTPException(status_code=403, detail="Esta postulación pertenece a otra fundación.")
    if application.status == "withdrawn":
        raise HTTPException(status_code=404, detail="La postulación ya no existe; quizá la retiraron.")
    if application.status in {"rejected", "approved"}:
        raise HTTPException(status_code=409, detail="Esta postulación ya está cerrada.")
    application.status = payload.status
    # Aprobar a una persona reserva el caso; todavía no significa adopción definitiva.
    if payload.status == "approved" and animal.status == "available":
        animal.status = "in_process"
    try:
        await db.commit()
        await db.refresh(application)
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo actualizar la postulación.") from exc
    return _foundation_response(application, animal, adopter)
