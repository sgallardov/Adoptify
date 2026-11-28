from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.adoption_profile import AdoptionProfile

ApplicationStatus = Literal["submitted", "reviewing", "invited_to_chat", "rejected", "withdrawn", "approved"]
FoundationApplicationStatus = Literal["reviewing", "invited_to_chat", "rejected", "approved"]


class AdoptionApplicationCreate(BaseModel):
    """Ficha breve, reutilizable desde el perfil, enviada voluntariamente a una fundación."""

    profile: AdoptionProfile
    message: str | None = Field(None, max_length=1000)

    @field_validator("message")
    @classmethod
    def clean_message(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None


class ApplicantSummary(BaseModel):
    """Nunca incluye correo, teléfono ni RUT."""

    user_id: int
    full_name: str


class FoundationApplicationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    animal_id: int
    animal_name: str
    status: ApplicationStatus
    applicant: ApplicantSummary
    profile: AdoptionProfile
    message: str | None
    created_at: datetime


class MyApplicationResponse(BaseModel):
    id: int
    animal_id: int
    animal_name: str
    animal_photo_url: str | None = None
    foundation_name: str
    status: ApplicationStatus
    created_at: datetime


class ApplicationStatusUpdate(BaseModel):
    status: FoundationApplicationStatus
