from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.animal import Size, Species

Housing = Literal["casa_patio", "casa_sin_patio", "departamento"]
YesNo = Literal["si", "no"]
HoursAlone = Literal["0_2", "2_5", "5_8", "8_mas"]
Activity = Literal["bajo", "medio", "alto"]
Experience = Literal["ninguna", "algo", "mucha"]
AgeGroup = Literal["cachorro", "adulto", "senior"]


class AdoptionProfile(BaseModel):
    """
    Formulario "Quiero adoptar" de la app: datos del hogar y preferencias para el motor de match (HU-05).
    Es opcional para la cuenta: quien solo reporta animales nunca lo completa.
    Una lista vacía en wanted_* significa "me da igual" y no entra al cálculo del match.
    """
    housing_type: Housing
    has_kids: YesNo
    has_pets: YesNo
    hours_alone: HoursAlone
    activity_level: Activity | None = None
    experience: Experience | None = None
    wanted_species: list[Species] = Field(..., min_length=1)
    wanted_sizes: list[Size] = Field(..., min_length=1)
    wanted_ages: list[AgeGroup] = []
    accepts_follow_up: bool = True
