from pydantic import BaseModel, ConfigDict


class AnimalResponse(BaseModel):
    """Datos públicos del animal, sin geometrías binarias ni relaciones ORM."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    foundation_id: int
    foundation_name: str | None
    name: str
    species: str
    breed: str | None
    age_months: int | None
    gender: str
    size: str
    energy_level: int
    description: str | None
    status: str
    photo_url: str | None
    latitude: float | None
    longitude: float | None


class NearbyAnimalResponse(AnimalResponse):
    """Animal encontrado en una búsqueda por cercanía, con su distancia al punto consultado."""
    distance_km: float
