"""Búsqueda de direcciones en Chile con Nominatim (OpenStreetMap)."""

import asyncio
import time

import httpx

from app.services.communes import find_commune

NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
# La política de Nominatim exige identificar la aplicación; no se envían datos personales
USER_AGENT = "Adoptify/1.0 (proyecto academico de adopcion animal)"
_MIN_INTERVAL_SECONDS = 1.0
_CACHE_SIZE = 256

_lock = asyncio.Lock()
_last_request = 0.0
_cache: dict[str, list[dict]] = {}


class GeocodingError(Exception):
    """El servicio de direcciones no respondió o respondió algo inesperado."""


def _commune_of(label: str) -> str | None:
    """Primera parte del lugar que es una comuna del catálogo.

    Nominatim ordena de lo más específico a lo más general ("Avenida Grecia, Ñuñoa, Santiago, ...").
    Se salta la primera parte (calle o lugar) para no confundir "Recoleta" (calle) con la comuna.
    """
    parts = [part.strip() for part in label.split(",")]
    for part in parts[1:] if len(parts) > 1 else parts:
        commune = find_commune(part)
        if commune:
            return commune
    return None


async def search_address(query: str, limit: int = 5) -> list[dict]:
    """Devuelve hasta `limit` lugares de Chile con `label`, `latitude` y `longitude`."""
    key = f"{query.strip().casefold()}|{limit}"
    if key in _cache:
        return _cache[key]

    global _last_request
    # Nominatim admite como máximo una consulta por segundo por aplicación
    async with _lock:
        wait = _MIN_INTERVAL_SECONDS - (time.monotonic() - _last_request)
        if wait > 0:
            await asyncio.sleep(wait)
        try:
            async with httpx.AsyncClient(timeout=8.0, headers={"User-Agent": USER_AGENT}) as client:
                response = await client.get(NOMINATIM_URL, params={
                    "q": query, "format": "jsonv2", "countrycodes": "cl", "limit": limit, "accept-language": "es",
                })
            response.raise_for_status()
            data = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise GeocodingError(str(exc)) from exc
        finally:
            _last_request = time.monotonic()

    if not isinstance(data, list):
        raise GeocodingError("Respuesta inesperada de Nominatim")
    results = [
        {
            "label": item["display_name"],
            "latitude": float(item["lat"]),
            "longitude": float(item["lon"]),
            "commune": _commune_of(item["display_name"]),
        }
        for item in data
        if item.get("display_name") and item.get("lat") and item.get("lon")
    ]
    if len(_cache) >= _CACHE_SIZE:
        _cache.pop(next(iter(_cache)))
    _cache[key] = results
    return results
