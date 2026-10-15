from pydantic import BaseModel, Field
from typing import Optional

class DatabaseStatus(BaseModel):
    connected: bool = Field(..., description="Indica si la base de datos respondió correctamente")
    postgis_version: Optional[str] = Field(None, description="Versión activa de la extensión PostGIS")

class HealthResponse(BaseModel):
    status: str = Field(..., description="Estado general del servicio ('ok' o 'error')", example="ok")
    service: str = Field(..., description="Nombre del servicio", example="adoptify-backend")
    environment: str = Field(..., description="Entorno actual de ejecución", example="development")
    database: DatabaseStatus
