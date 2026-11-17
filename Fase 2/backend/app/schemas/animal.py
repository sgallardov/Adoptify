from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, computed_field, field_validator, model_validator

from app.services import storage
from app.services.communes import COMMUNES

Species = Literal["perro", "gato"]
Gender = Literal["macho", "hembra"]
Size = Literal["pequeño", "mediano", "grande"]
AnimalStatus = Literal["available", "adopted", "in_process"]
KeepingPlaceType = Literal["refugio", "hogar_temporal"]


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
    keeping_place_type: KeepingPlaceType | None = None
    keeping_place_address: str | None = None


class AnimalMutationResponse(PublicAnimalResponse):
    """Respuesta de crear o editar: no reexpone el lugar privado de resguardo."""
    latitude: float | None
    longitude: float | None


class InterestedUserResponse(BaseModel):
    """Información mínima de un adoptante interesado; nunca incluye datos de contacto ni RUT."""

    user_id: int
    full_name: str
    favorited_at: datetime


class AnimalInterestedResponse(BaseModel):
    """Interesados por animal, visible solo a la fundación dueña o al administrador."""

    animal_id: int
    animal_name: str
    animal_status: AnimalStatus
    interested: list[InterestedUserResponse]


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
    # Una publicación nueva debe tener una foto: es esencial para que los adoptantes
    # puedan reconocer al animal. La columna sigue aceptando nulos por los registros
    # históricos que se crearon antes de esta regla.
    photo_url: str = Field(..., min_length=1, max_length=500)
    keeping_place_type: KeepingPlaceType
    keeping_place_address: str = Field(..., min_length=1, max_length=255)
    latitude: float | None = Field(None, ge=-90, le=90)
    longitude: float | None = Field(None, ge=-180, le=180)
    foundation_id: int | None = Field(None, description="Solo para administradores; las fundaciones usan la suya")

    # La app y el portal devuelven el enlace firmado que recibieron al subir la foto: se guarda la referencia
    @field_validator("photo_url", mode="before")
    @classmethod
    def photo_as_reference(cls, value):
        return storage.to_reference(value) if isinstance(value, str) else value

    @field_validator("photo_url")
    @classmethod
    def validate_photo_url(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Debes subir una foto del animal")
        return value

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        clean = value.strip()
        if not clean:
            raise ValueError("El nombre no puede estar vacío")
        return clean

    @field_validator("keeping_place_address")
    @classmethod
    def validate_keeping_place_address(cls, value: str) -> str:
        clean = value.strip()
        if not clean:
            raise ValueError("Indica el lugar donde se encuentra el animal")
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
    keeping_place_type: KeepingPlaceType | None = None
    keeping_place_address: str | None = Field(None, min_length=1, max_length=255)
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

    @field_validator("keeping_place_type", "keeping_place_address", mode="before")
    @classmethod
    def reject_null_keeping_place(cls, value):
        # Omitir el campo conserva animales antiguos sin información; enviarlo como null no lo borra.
        if value is None:
            raise ValueError("Este campo no puede ser nulo")
        return value

    @field_validator("keeping_place_address")
    @classmethod
    def validate_updated_keeping_place_address(cls, value: str | None) -> str | None:
        clean = value.strip()
        if not clean:
            raise ValueError("Indica el lugar donde se encuentra el animal")
        return clean

    @model_validator(mode="after")
    def validate_coordinates(self):
        sent = self.model_fields_set
        if ("latitude" in sent) != ("longitude" in sent) or (
            "latitude" in sent and (self.latitude is None or self.longitude is None)
        ):
            raise ValueError("Debes indicar latitud y longitud juntas")
        return self
