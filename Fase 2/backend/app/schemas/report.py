from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ReportCreate(BaseModel):
    """Datos para reportar un perro abandonado: dónde está y cómo se ve."""
    latitude: float = Field(..., ge=-90, le=90, description="Latitud donde se vio al perro")
    longitude: float = Field(..., ge=-180, le=180, description="Longitud donde se vio al perro")
    description: str = Field(..., min_length=10, max_length=1000, description="Descripción del perro y su estado")
    photo_url: str | None = Field(None, max_length=500)


class ReportResponse(BaseModel):
    """Datos públicos del reporte. No incluye quién lo hizo para proteger su identidad."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    description: str
    photo_url: str | None
    status: str
    latitude: float
    longitude: float
    created_at: datetime


class NearbyReportResponse(ReportResponse):
    """Reporte encontrado en una búsqueda por cercanía, con su distancia al punto consultado."""
    distance_km: float
