from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, computed_field, field_validator, model_validator

from app.services import storage
from app.services.communes import COMMUNES

Species = Literal["perro", "gato"]
Gender = Literal["macho", "hembra"]
Size = Literal["pequeño", "mediano", "grande"]
AnimalStatus = Literal["available", "adopted", "in_process"]


class PublicAnimalResponse(BaseModel):
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
    public_commune: str | None = None

    @computed_field
    @property
    def commune_point(self) -> tuple[float, float] | None:
        point = COMMUNES.get(self.public_commune)
        return tuple(point) if point else None


class MatchAnimalResponse(BaseModel):
    """Tarjeta del match: sin zona ni comuna, para no mostrar dónde está el animal."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    foundation_name: str | None
    name: str
    species: str
    breed: str | None
    age_months: int | None
    gender: str
    size: str
    energy_level: int
    description: str | None
    photo_url: str | None
    match_score: float = 0.0


class AnimalResponse(PublicAnimalResponse):
    """Ficha privada, solo tras autorizar el acceso a la fundación."""
    latitude: float | None
    longitude: float | None


class CommuneInput(BaseModel):
    public_commune: str | None = Field(None, max_length=100)

    @field_validator("public_commune")
    @classmethod
    def validate_commune(cls, value):
        if value is not None and value not in COMMUNES:
            raise ValueError("Selecciona una comuna del listado")
        return value


class AnimalCreate(CommuneInput):
    """Datos para publicar un animal. La fundación dueña sale de la sesión, no del cuerpo (salvo para admin)."""
    name: str = Field(..., min_length=1, max_length=100)
    species: Species
    breed: str | None = Field(None, max_length=100)
    age_months: int | None = Field(None, ge=0, le=360)
    gender: Gender
    size: Size
    energy_level: int = Field(3, ge=1, le=5, description="Escala de 1 (tranquilo) a 5 (muy activo)")
    description: str | None = Field(None, max_length=2000)
    status: AnimalStatus = "available"
    photo_url: str | None = Field(None, max_length=500)
    latitude: float | None = Field(None, ge=-90, le=90)
    longitude: float | None = Field(None, ge=-180, le=180)
    foundation_id: int | None = Field(None, description="Solo para administradores; las fundaciones usan la suya")

    # La app y el portal devuelven el enlace firmado que recibieron al subir la foto: se guarda la referencia
    @field_validator("photo_url", mode="before")
    @classmethod
    def photo_as_reference(cls, value):
        return storage.to_reference(value) if isinstance(value, str) else value

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        clean = value.strip()
        if not clean:
            raise ValueError("El nombre no puede estar vacío")
        return clean

    @model_validator(mode="after")
    def validate_coordinates(self):
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("Debes indicar latitud y longitud juntas")
        return self


class AnimalUpdate(CommuneInput):
    """Cambios parciales sobre un animal: solo se modifican los campos enviados."""
    name: str | None = Field(None, min_length=1, max_length=100)
    species: Species | None = None
    breed: str | None = Field(None, max_length=100)
    age_months: int | None = Field(None, ge=0, le=360)
    gender: Gender | None = None
    size: Size | None = None
    energy_level: int | None = Field(None, ge=1, le=5)
    description: str | None = Field(None, max_length=2000)
    status: AnimalStatus | None = None
    photo_url: str | None = Field(None, max_length=500)
    latitude: float | None = Field(None, ge=-90, le=90)
    longitude: float | None = Field(None, ge=-180, le=180)

    # La app y el portal devuelven el enlace firmado que recibieron al subir la foto: se guarda la referencia
    @field_validator("photo_url", mode="before")
    @classmethod
    def photo_as_reference(cls, value):
        return storage.to_reference(value) if isinstance(value, str) else value

    @field_validator("name", "species", "gender", "size", "energy_level", "status", mode="before")
    @classmethod
    def reject_null(cls, value):
        # Son obligatorios en la tabla: se pueden omitir, pero no dejar en null
        if value is None:
            raise ValueError("Este campo no puede ser nulo")
        return value.strip() if isinstance(value, str) else value

    @model_validator(mode="after")
    def validate_coordinates(self):
        sent = self.model_fields_set
        if ("latitude" in sent) != ("longitude" in sent) or (
            "latitude" in sent and (self.latitude is None or self.longitude is None)
        ):
            raise ValueError("Debes indicar latitud y longitud juntas")
        return self
