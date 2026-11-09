from pydantic import BaseModel, ConfigDict


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
