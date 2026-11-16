from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.adoption_profile import Housing
from app.schemas.animal import Size

FosterSpecies = Literal["perro", "gato", "ambos"]
FosterStatus = Literal["pending", "approved", "rejected"]


def _clean(value: str, field: str) -> str:
    clean = " ".join(value.split())
    if not clean:
        raise ValueError(f"{field} es obligatorio.")
    return clean


class FosterApplicationIn(BaseModel):
    """Lo que completa el adoptante (HU-B). Todo es obligatorio. Nombre y correo salen de su cuenta."""
    species: FosterSpecies
    sizes: list[Size] = Field(..., min_length=1, description="Uno o más: pequeño, mediano, grande")
    space: Housing = Field(..., description="casa_patio, casa_sin_patio o departamento")
    max_animals: int = Field(..., ge=1, le=10, description="Cuántos animales puede cuidar a la vez")
    max_days: int = Field(..., ge=1, le=365, description="Días máximos que puede tener a un animal")
    availability: str = Field(..., max_length=120, description="Texto corto: 'desde ya', 'fines de semana'…")
    phone: str = Field(..., max_length=30)
    address: str = Field(..., max_length=255, description="Privada: solo la ven las fundaciones")

    @field_validator("sizes")
    @classmethod
    def unique_sizes(cls, value: list[str]) -> list[str]:
        return list(dict.fromkeys(value))

    @field_validator("availability")
    @classmethod
    def validate_availability(cls, value: str) -> str:
        return _clean(value, "La disponibilidad")

    @field_validator("address")
    @classmethod
    def validate_address(cls, value: str) -> str:
        clean = _clean(value, "La dirección")
        if len(clean) < 5:
            raise ValueError("Escribe la dirección completa (calle, número y comuna).")
        return clean

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, value: str) -> str:
        clean = _clean(value, "El teléfono")
        digits = "".join(ch for ch in clean if ch.isdigit())
        if not 8 <= len(digits) <= 15:
            raise ValueError("Escribe un teléfono válido, por ejemplo +56 9 1234 5678.")
        return clean


class FosterApplicationOut(BaseModel):
    """Postulación vista por su dueño: incluye su propia dirección y el estado."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    species: FosterSpecies
    sizes: list[Size]
    space: Housing
    max_animals: int
    max_days: int
    availability: str
    phone: str
    address: str
    status: FosterStatus
    created_at: datetime
    updated_at: datetime


class FosterApplicationForFoundation(BaseModel):
    """
    Postulación vista por una fundación (GET /foster-applications): incluye el contacto completo del postulante
    (nombre y correo de su cuenta, teléfono y dirección), que el adoptante no muestra a nadie más.
    """
    id: int
    full_name: str
    email: str
    phone: str
    address: str
    species: FosterSpecies
    sizes: list[Size]
    space: Housing
    max_animals: int
    max_days: int
    availability: str
    status: FosterStatus
    decided_by_foundation_name: str | None
    decided_at: datetime | None
    # La fundación que consulta puede aprobar, rechazar o volver a pendiente: solo si está pendiente o la decidió ella
    can_decide: bool
    created_at: datetime


class FosterDecision(BaseModel):
    """Decisión de una fundación. 'pending' deshace una decisión propia."""
    status: FosterStatus
