from pydantic import BaseModel


class GeocodeResult(BaseModel):
    """Un lugar encontrado para la dirección buscada."""

    label: str
    latitude: float
    longitude: float
    # Comuna del catálogo reconocida en el lugar (sin distinguir tildes); null si no se reconoce
    commune: str | None = None
