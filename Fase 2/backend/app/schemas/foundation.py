from pydantic import BaseModel

from app.schemas.animal import AnimalResponse


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
    latitude: float | None
    longitude: float | None
    animals: list[AnimalResponse]
