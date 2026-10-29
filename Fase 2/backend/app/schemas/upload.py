from pydantic import BaseModel


class UploadResponse(BaseModel):
    """Enlace de la imagen subida, para guardarlo en photo_url."""
    url: str
