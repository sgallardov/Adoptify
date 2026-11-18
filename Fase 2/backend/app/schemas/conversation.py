from datetime import datetime

from pydantic import BaseModel, Field, field_validator

MAX_MESSAGE_LENGTH = 1000


class ConversationCreate(BaseModel):
    """La fundación abre el chat con un adoptante vinculado (like, postulación o hogar temporal)."""

    user_id: int = Field(..., gt=0)


class LastMessage(BaseModel):
    body: str
    created_at: datetime
    from_foundation: bool


class ConversationOut(BaseModel):
    """Nunca incluye correo, teléfono ni RUT del adoptante."""

    id: int
    foundation_id: int
    foundation_name: str
    user_id: int
    user_name: str
    created_at: datetime
    last_message: LastMessage | None


class MessageCreate(BaseModel):
    body: str = Field(..., min_length=1, max_length=MAX_MESSAGE_LENGTH)

    @field_validator("body")
    @classmethod
    def not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("El mensaje no puede estar vacío.")
        return value


class MessageOut(BaseModel):
    id: int
    body: str
    created_at: datetime
    # True si lo escribió alguien de la fundación; así cada lado sabe de qué color pintarlo
    from_foundation: bool
    mine: bool
