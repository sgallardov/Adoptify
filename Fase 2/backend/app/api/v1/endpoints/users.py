from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.auth import get_current_user
from app.db.database import get_db
from app.models.user import User
from app.schemas.adoption_profile import AdoptionProfile
from app.services.adoption_profile import to_preferences

router = APIRouter()


@router.get(
    "/me/adoption-profile",
    response_model=AdoptionProfile | None,
    summary="Obtener el formulario 'Quiero adoptar' de la sesión actual",
    responses={401: {"description": "Token ausente, inválido o expirado"}},
)
async def get_adoption_profile(current_user: User = Depends(get_current_user)):
    """Retorna null si la persona aún no lo completó (solo usa la app para reportar)."""
    saved = (current_user.preferences or {}).get("adoption_profile")
    return AdoptionProfile.model_validate(saved) if saved else None


@router.put(
    "/me/adoption-profile",
    response_model=AdoptionProfile,
    summary="Crear o actualizar el formulario 'Quiero adoptar'",
    responses={
        401: {"description": "Token ausente, inválido o expirado"},
        403: {"description": "Solo las cuentas de adoptante pueden adoptar"},
    },
)
async def save_adoption_profile(
    payload: AdoptionProfile,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "adopter":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo las cuentas de adoptante pueden adoptar")
    # Se asigna un diccionario nuevo: SQLAlchemy no detecta cambios dentro de una columna JSON
    current_user.preferences = to_preferences(payload)
    await db.commit()
    return payload
