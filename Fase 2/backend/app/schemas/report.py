from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.services import storage

ReportSpecies = Literal["perro", "gato", "otro"]
ReportSize = Literal["pequeño", "mediano", "grande"]
# Mismas opciones que reportOptions (portal) y map_service.dart (app)
ReportCondition = Literal[
    "bien", "desnutrido", "deshidratado", "herido", "sangrando", "cojea", "atropellado", "no_se_mueve",
    "enfermo", "problemas_piel", "parasitos", "problemas_ojos", "prenada", "con_crias", "deplorable",
]
ReportBehavior = Literal[
    "tranquilo", "amistoso", "jugueton", "sigue_personas", "decaido", "asustado", "se_esconde",
    "huye", "nervioso", "desconfiado", "ruidoso", "protector", "agresivo",
]


class ReportCreate(BaseModel):
    """Datos para reportar una mascota abandonada: dónde está, cómo es, cómo se encuentra y comentarios."""
    latitude: float = Field(..., ge=-90, le=90, description="Latitud donde se vio al animal")
    longitude: float = Field(..., ge=-180, le=180, description="Longitud donde se vio al animal")
    species: ReportSpecies = Field(..., description="Tipo de animal")
    size: ReportSize
    weight_kg: float | None = Field(None, gt=0, le=150, description="Peso aproximado en kilos")
    color: str = Field(..., min_length=2, max_length=60)
    features: str | None = Field(None, max_length=300, description="Características: collar, manchas, raza aparente, etc.")
    conditions: list[ReportCondition] = Field(
        ..., min_length=1, description="Estado en que se encuentra: uno o varios"
    )
    behaviors: list[ReportBehavior] = Field(default_factory=list, description="Cómo reacciona al acercarse: ninguno, uno o varios")
    description: str = Field(..., min_length=10, max_length=1000, description="Comentarios sobre la situación")
    photo_url: str | None = Field(None, max_length=500)

    # La app y el portal devuelven el enlace firmado que recibieron al subir la foto: se guarda la referencia
    @field_validator("photo_url", mode="before")
    @classmethod
    def photo_as_reference(cls, value):
        return storage.to_reference(value) if isinstance(value, str) else value

    @field_validator("color", "description", mode="before")
    @classmethod
    def strip_required(cls, value):
        return value.strip() if isinstance(value, str) else value

    @field_validator("conditions", "behaviors")
    @classmethod
    def without_duplicates(cls, values: list[str]) -> list[str]:
        return list(dict.fromkeys(values))

    @field_validator("features", mode="before")
    @classmethod
    def strip_optional(cls, value):
        if isinstance(value, str):
            value = value.strip()
            return value or None
        return value


class ReportResponse(BaseModel):
    """Datos públicos del reporte. No incluye quién lo hizo para proteger su identidad.
    Los campos de la ficha pueden venir vacíos en reportes creados antes de agregarlos."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    species: str | None
    size: str | None
    weight_kg: float | None
    color: str | None
    features: str | None
    conditions: list[str]
    behaviors: list[str]
    description: str
    photo_url: str | None
    status: str
    seen_at: datetime | None = None
    taken_at: datetime | None = None
    foundation_name: str | None = None
    latitude: float
    longitude: float
    created_at: datetime


    # Los reportes anteriores a la ficha guardan NULL: se entregan como lista vacía
    @field_validator("conditions", "behaviors", mode="before")
    @classmethod
    def none_as_empty(cls, value):
        return value or []


class NearbyReportResponse(ReportResponse):
    """Reporte encontrado en una búsqueda por cercanía, con su distancia al punto consultado."""
    distance_km: float
