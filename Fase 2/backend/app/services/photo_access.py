"""Fotos privadas: solo quien tiene sesión iniciada recibe enlaces para verlas.

Middleware de las respuestas JSON de /api/v1: cada photo_url (y el url de POST /uploads) que apunta a
una foto del bucket privado se cambia por un enlace firmado que caduca, si la petición trae un token
válido; si no, por null. Así no hay que acordarse de firmar en cada endpoint (animales, reportes,
fundaciones con sus animales, la subida...). Los enlaces externos (Unsplash) y las fotos locales de
/uploads pasan tal cual.
"""

import json
import logging

import httpx
from starlette.requests import Request
from starlette.responses import Response

from app.core.config import settings
from app.core.security import decode_access_token
from app.services import storage

logger = logging.getLogger("adoptify")

PHOTO_KEYS = ("photo_url", "url")


def _has_session(request: Request) -> bool:
    scheme, _, token = request.headers.get("authorization", "").partition(" ")
    return scheme.lower() == "bearer" and decode_access_token(token) is not None


def _photo_slots(data, found: list[tuple[dict, str, str]]) -> None:
    """Junta (objeto, clave, archivo) de cada foto del bucket dentro de la respuesta."""
    if isinstance(data, dict):
        for key, value in data.items():
            filename = storage.filename_of(value) if key in PHOTO_KEYS and isinstance(value, str) else None
            if filename:
                found.append((data, key, filename))
            else:
                _photo_slots(value, found)
    elif isinstance(data, list):
        for item in data:
            _photo_slots(item, found)


async def sign_photo_urls(request: Request, call_next):
    response = await call_next(request)
    if (
        not settings.storage_enabled
        or not request.url.path.startswith(settings.API_V1_STR)
        or not response.headers.get("content-type", "").startswith("application/json")
    ):
        return response

    body = b"".join([chunk async for chunk in response.body_iterator])
    headers = {k: v for k, v in response.headers.items() if k.lower() != "content-length"}
    try:
        data = json.loads(body)
    except ValueError:
        return Response(body, status_code=response.status_code, headers=headers)

    slots: list[tuple[dict, str, str]] = []
    _photo_slots(data, slots)
    if not slots:
        return Response(body, status_code=response.status_code, headers=headers)

    signed: dict[str, str] = {}
    if _has_session(request):
        try:
            signed = await storage.signed_urls({filename for _, _, filename in slots})
        except (storage.StorageError, httpx.HTTPError) as exc:
            # Sin Storage la app sigue funcionando: los animales y reportes llegan, solo que sin foto
            logger.warning("No se pudieron firmar las fotos: %s", exc)
    for container, key, filename in slots:
        container[key] = signed.get(filename)

    return Response(
        json.dumps(data, ensure_ascii=False).encode("utf-8"),
        status_code=response.status_code,
        headers=headers,
    )
