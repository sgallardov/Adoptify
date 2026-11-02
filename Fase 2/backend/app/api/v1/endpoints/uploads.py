import asyncio
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, status

from app.api.v1.endpoints.auth import get_current_user
from app.core.config import settings
from app.models.user import User
from app.schemas.upload import UploadResponse

router = APIRouter()

# Se reconoce el formato por los primeros bytes del archivo, no por su nombre ni su Content-Type
JPEG_SIGNATURE = b"\xff\xd8\xff"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def detect_extension(content: bytes) -> str | None:
    if content.startswith(JPEG_SIGNATURE):
        return "jpg"
    if content.startswith(PNG_SIGNATURE):
        return "png"
    return None


@router.post(
    "",
    response_model=UploadResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Subir una foto (JPG o PNG)",
    description=(
        "Recibe una imagen en multipart/form-data (campo 'file') y devuelve su URL para guardarla en "
        "photo_url de un animal o reporte. Máximo 5 MB."
    ),
    responses={
        401: {"description": "Se requiere iniciar sesión"},
        413: {"description": "La imagen supera el tamaño máximo"},
        415: {"description": "El archivo no es una imagen JPG o PNG"},
    },
)
async def upload_image(
    file: UploadFile,
    request: Request,
    current_user: User = Depends(get_current_user),
):
    max_bytes = settings.MAX_UPLOAD_MB * 1024 * 1024
    # Se lee un byte de más para detectar archivos pesados sin cargarlos completos en memoria
    content = await file.read(max_bytes + 1)
    if len(content) > max_bytes:
        raise HTTPException(
            status_code=413,
            detail=f"La imagen es muy pesada. El máximo es {settings.MAX_UPLOAD_MB} MB.",
        )
    extension = detect_extension(content)
    if extension is None:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="El archivo no es una imagen válida. Usa JPG o PNG.",
        )

    # Nombre aleatorio: nunca se usa el nombre que envía el cliente
    filename = f"{uuid.uuid4().hex}.{extension}"
    directory = Path(settings.UPLOAD_DIR)
    try:
        await asyncio.to_thread(directory.mkdir, parents=True, exist_ok=True)
        await asyncio.to_thread((directory / filename).write_bytes, content)
    except OSError as exc:
        raise HTTPException(status_code=503, detail="No se pudo guardar la imagen.") from exc

    base_url = (settings.PUBLIC_BASE_URL or str(request.base_url)).rstrip("/")
    return UploadResponse(url=f"{base_url}/uploads/{filename}")
