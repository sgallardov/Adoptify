from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class CommentCreate(BaseModel):
    """Comentario anónimo en un reporte."""
    body: str = Field(..., min_length=1, max_length=500, description="Texto del comentario")

    @field_validator("body", mode="before")
    @classmethod
    def strip_body(cls, value):
        return value.strip() if isinstance(value, str) else value


class CommentResponse(BaseModel):
    """Comentario público: nunca incluye quién lo escribió, solo si es de quien consulta."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    body: str
    created_at: datetime
    is_mine: bool = False


class LikesResponse(BaseModel):
    """Cuántas personas marcaron "me enteré" y si quien consulta es una de ellas."""
    count: int
    liked: bool
