from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.v1.endpoints.auth import get_current_user
from app.models.user import User
from app.schemas.geocoding import GeocodeResult
from app.services import geocoding

router = APIRouter()


@router.get(
    "",
    response_model=list[GeocodeResult],
    summary="Buscar una dirección en Chile",
    description=(
        "Solo fundaciones y administradores, para ubicar a un animal sin escribir coordenadas. "
        "Usa Nominatim (© colaboradores de OpenStreetMap, ODbL) con un máximo de una consulta por segundo."
    ),
)
async def geocode(
    q: str = Query(..., min_length=3, max_length=200, description="Dirección o lugar, por ejemplo 'Av. Grecia 100, Ñuñoa'"),
    current_user: User = Depends(get_current_user),
):
    if current_user.role not in ("foundation", "admin"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Tu cuenta no puede buscar direcciones.")
    try:
        return await geocoding.search_address(q.strip())
    except geocoding.GeocodingError as exc:
        raise HTTPException(status_code=503, detail="No pudimos buscar la dirección. Inténtalo en unos segundos.") from exc
