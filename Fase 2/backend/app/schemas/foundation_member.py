from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class MemberBase(BaseModel):
    name: str = Field(..., max_length=150)
    contribution: Decimal | None = Field(None, ge=0, max_digits=12, decimal_places=2, description="Uso interno; no se publica")
    joined_at: date
    is_public: bool = False

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        clean = value.strip()
        if not clean:
            raise ValueError("El nombre del socio es obligatorio.")
        return clean


class MemberCreate(MemberBase):
    # Solo lo usa un admin (no tiene fundación propia); para una fundación se ignora
    foundation_id: int | None = None


class MemberUpdate(MemberBase):
    pass


class MemberResponse(BaseModel):
    """Vista privada: incluye el aporte."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    foundation_id: int
    name: str
    contribution: Decimal | None
    joined_at: date
    is_public: bool
    created_at: datetime


class PublicMemberResponse(BaseModel):
    """Vista pública: solo nombre y fecha de ingreso."""
    model_config = ConfigDict(from_attributes=True)

    name: str
    joined_at: date
