from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

ReportSpecies = Literal["perro", "gato", "otro"]
ReportSize = Literal["pequeño", "mediano", "grande"]
ReportCondition = Literal["bien", "desnutrido", "herido", "enfermo", "deplorable"]
ReportBehavior = Literal["tranquilo", "asustado", "agresivo"]


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
        ..., min_length=1, description="Estado en que se encuentra: uno o varios; 'bien' no se combina con otros"
    )
    behaviors: list[ReportBehavior] = Field(default_factory=list, description="Cómo reacciona al acercarse: ninguno, uno o varios")
    description: str = Field(..., min_length=10, max_length=1000, description="Comentarios sobre la situación")
    photo_url: str | None = Field(None, max_length=500)

    @field_validator("color", "description", mode="before")
    @classmethod
    def strip_required(cls, value):
        return value.strip() if isinstance(value, str) else value

    @field_validator("conditions", "behaviors")
    @classmethod
    def without_duplicates(cls, values: list[str]) -> list[str]:
        return list(dict.fromkeys(values))

    @model_validator(mode="after")
    def good_is_exclusive(self):
        if "bien" in self.conditions and len(self.conditions) > 1:
            raise ValueError("El estado 'bien' no se puede combinar con otros estados.")
        return self

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
