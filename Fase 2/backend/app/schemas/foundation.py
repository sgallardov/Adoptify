from pydantic import BaseModel, Field, field_validator

from app.schemas.animal import PublicAnimalResponse
from app.services import storage

DESCRIPTION_MIN = 20
DESCRIPTION_MAX = 1000


class FoundationResponse(BaseModel):
    """Datos públicos de la fundación (sin RUT ni geometría cruda) y sus animales disponibles para adopción."""
    id: int
    name: str
    description: str | None
    address: str | None
    commune: str | None
    city: str
    phone: str | None
    email: str
    is_verified: bool
    photo_url: str | None
    latitude: float | None
    longitude: float | None
    # Solo con lat/lng en GET /foundations: distancia en km a quien busca
    distance_km: float | None = None
    animals: list[PublicAnimalResponse]


class FoundationProfileUpdate(BaseModel):
    """Perfil que edita la propia fundación (PUT /foundations/me). La descripción es obligatoria."""
    description: str = Field(..., max_length=DESCRIPTION_MAX)
    photo_url: str | None = Field(None, max_length=500)

    @field_validator("description")
    @classmethod
    def validate_description(cls, value: str) -> str:
        clean = value.strip()
        if len(clean) < DESCRIPTION_MIN:
            raise ValueError(f"La descripción debe tener al menos {DESCRIPTION_MIN} caracteres.")
        return clean

    # La app devuelve el enlace firmado que recibió al subir la foto: se guarda la referencia
    @field_validator("photo_url", mode="before")
    @classmethod
    def photo_as_reference(cls, value):
        return storage.to_reference(value) if isinstance(value, str) else value
