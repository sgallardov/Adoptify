from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class VeterinaryClinicResponse(BaseModel):
    """Clínica veterinaria pública (datos de OpenStreetMap), sin la geometría cruda."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    address: str | None
    commune: str | None
    phone: str | None
    opening_hours: str | None
    emergency: bool
    latitude: float
    longitude: float


class VeterinaryClinicCreate(BaseModel):
    """Alta administrativa: la fuente describe el origen, pero no se publica."""

    name: str = Field(..., min_length=1, max_length=255)
    phone: str | None = Field(None, max_length=50)
    address: str | None = Field(None, max_length=255)
    commune: str | None = Field(None, max_length=100)
    opening_hours: str | None = Field(None, max_length=255)
    emergency: bool = False
    source: Literal["manual", "importacion", "fundacion"] = "manual"
    is_active: bool = True
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)


class VeterinaryClinicUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=255)
    phone: str | None = Field(None, max_length=50)
    address: str | None = Field(None, max_length=255)
    commune: str | None = Field(None, max_length=100)
    opening_hours: str | None = Field(None, max_length=255)
    emergency: bool | None = None
    source: Literal["manual", "importacion", "fundacion"] | None = None
    is_active: bool | None = None
    latitude: float | None = Field(None, ge=-90, le=90)
    longitude: float | None = Field(None, ge=-180, le=180)

    @model_validator(mode="after")
    def validate_coordinates(self):
        sent = self.model_fields_set
        if ("latitude" in sent) != ("longitude" in sent) or (
            "latitude" in sent and (self.latitude is None or self.longitude is None)
        ):
            raise ValueError("Debes indicar latitud y longitud juntas")
        return self
