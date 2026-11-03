"""Fotos en Supabase Storage, en un bucket PRIVADO: solo las ven usuarios con sesión iniciada.

En la BD se guarda una referencia ("storage:<archivo>"), nunca un enlace. Al responder, la API la
cambia por un enlace firmado que caduca (ver photo_access.py) si quien pide tiene sesión, o por null.
"""

import logging
import time
from urllib.parse import urlsplit

import httpx

from app.core.config import settings

logger = logging.getLogger("adoptify")

CONTENT_TYPES = {"jpg": "image/jpeg", "png": "image/png"}
REFERENCE_PREFIX = "storage:"
# Duración de cada enlace firmado (PHOTO_LINK_HOURS); se reutiliza hasta que le quedan menos de 10 minutos,
# así todos reciben el mismo enlace y la CDN de Supabase y el teléfono no vuelven a descargar la foto
SIGNED_URL_SECONDS = settings.PHOTO_LINK_HOURS * 60 * 60
# Cada foto tiene un nombre aleatorio y nunca cambia: la CDN y los navegadores pueden guardarla un año
PHOTO_CACHE_CONTROL = "max-age=31536000"
_REUSE_MARGIN_SECONDS = 10 * 60
_signed_cache: dict[str, tuple[str, float]] = {}


class StorageError(Exception):
    """Supabase Storage no aceptó el archivo o no respondió."""


def _headers() -> dict[str, str]:
    key = settings.SUPABASE_SERVICE_KEY or ""
    headers = {"apikey": key}
    # Las llaves antiguas (service_role) son JWT y también van como Bearer; las nuevas (sb_secret_...) no
    if key.startswith("eyJ"):
        headers["Authorization"] = f"Bearer {key}"
    return headers


def _base_url() -> str:
    return (settings.SUPABASE_URL or "").rstrip("/")


def reference(filename: str) -> str:
    """Lo que se guarda en photo_url para una foto del bucket."""
    return f"{REFERENCE_PREFIX}{filename}"


def filename_of(value: str | None) -> str | None:
    """
    Nombre del archivo si el valor apunta a una foto de nuestro bucket, o None si es otra cosa
    (un enlace externo como Unsplash o una foto local de /uploads).
    Reconoce la referencia guardada y los enlaces del bucket (públicos antiguos y firmados), que es
    lo que la app o el portal devuelven al crear un reporte o un animal con la foto que acaban de subir.
    """
    if not value:
        return None
    if value.startswith(REFERENCE_PREFIX):
        return value[len(REFERENCE_PREFIX):] or None
    if not settings.SUPABASE_URL:
        return None
    url = urlsplit(value)
    if f"{url.scheme}://{url.netloc}" != _base_url():
        return None
    for kind in ("public", "sign"):
        prefix = f"/storage/v1/object/{kind}/{settings.SUPABASE_BUCKET}/"
        if url.path.startswith(prefix):
            return url.path[len(prefix):] or None
    return None


def to_reference(value: str | None) -> str | None:
    """Normaliza el photo_url que llega en un formulario: nuestras fotos se guardan como referencia."""
    filename = filename_of(value)
    return reference(filename) if filename else value


async def signed_urls(filenames: set[str]) -> dict[str, str]:
    """
    Enlaces firmados (caducan en SIGNED_URL_SECONDS) para varias fotos, con una sola llamada a Supabase.
    Si una foto ya tiene un enlace vigente, se reutiliza: así el teléfono no la vuelve a descargar.
    """
    now = time.time()
    result: dict[str, str] = {}
    for name in filenames:
        cached = _signed_cache.get(name)
        if cached and cached[1] - now > _REUSE_MARGIN_SECONDS:
            result[name] = cached[0]
    missing = sorted(filenames - result.keys())
    if not missing:
        return result
    body = {"expiresIn": SIGNED_URL_SECONDS, "paths": missing}
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.post(
            f"{_base_url()}/storage/v1/object/sign/{settings.SUPABASE_BUCKET}", json=body, headers=_headers()
        )
    if response.status_code >= 400:
        raise StorageError(f"Supabase Storage respondió {response.status_code} al firmar")
    for item in response.json():
        signed = item.get("signedURL") or item.get("signedUrl")
        if item.get("error") or not signed:
            continue  # la foto ya no existe en el bucket
        url = f"{_base_url()}/storage/v1{signed}"
        _signed_cache[item["path"]] = (url, now + SIGNED_URL_SECONDS)
        result[item["path"]] = url
    return result


async def upload_photo(filename: str, content: bytes, extension: str) -> str:
    """Sube la foto al bucket privado y devuelve la referencia que se guarda en photo_url."""
    url = f"{_base_url()}/storage/v1/object/{settings.SUPABASE_BUCKET}/{filename}"
    headers = {
        **_headers(),
        "Content-Type": CONTENT_TYPES[extension],
        "x-upsert": "false",
        "cache-control": PHOTO_CACHE_CONTROL,
    }
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(url, content=content, headers=headers)
    except httpx.HTTPError as exc:
        raise StorageError("Supabase Storage no respondió") from exc
    if response.status_code >= 400:
        raise StorageError(f"Supabase Storage respondió {response.status_code}")
    return reference(filename)


async def make_bucket_private() -> None:
    """Pasa el bucket a privado: los enlaces públicos antiguos dejan de funcionar."""
    body = {"public": False, "file_size_limit": settings.MAX_UPLOAD_MB * 1024 * 1024,
            "allowed_mime_types": list(CONTENT_TYPES.values())}
    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.put(
            f"{_base_url()}/storage/v1/bucket/{settings.SUPABASE_BUCKET}", json=body, headers=_headers()
        )
    if response.status_code >= 400:
        raise StorageError(f"No se pudo hacer privado el bucket: {response.status_code} {response.text[:200]}")


async def ensure_bucket() -> str:
    """Crea el bucket privado si no existe (se usa una vez al configurar el proyecto)."""
    body = {
        "id": settings.SUPABASE_BUCKET,
        "name": settings.SUPABASE_BUCKET,
        "public": False,
        "file_size_limit": settings.MAX_UPLOAD_MB * 1024 * 1024,
        "allowed_mime_types": list(CONTENT_TYPES.values()),
    }
    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(f"{_base_url()}/storage/v1/bucket", json=body, headers=_headers())
    if response.status_code < 400:
        return "creado"
    # 409 o 400 "already exists": ya estaba
    if "already exists" in response.text.lower() or response.status_code == 409:
        return "ya existía"
    raise StorageError(f"No se pudo crear el bucket: {response.status_code} {response.text[:200]}")
