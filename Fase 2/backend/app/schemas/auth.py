import re
from pydantic import BaseModel, Field, field_validator

# Expresión regular que valida la sintaxis de un RUT chileno (con o sin puntos, con guión y DV 0-9 o K)
RUT_REGEX = r"^(\d{1,2}(?:\.\d{3}){2}-[\dkK]|\d{7,8}-[\dkK])$"

class RUTValidateRequest(BaseModel):
    """
    Payload de entrada para validar el RUT institucional de una fundación.
    """
    rut: str = Field(
        ...,
        description="RUT chileno con guión y dígito verificador (con o sin puntos)",
        examples=["76.452.189-4", "12345678-2"]
    )

    @field_validator("rut")
    @classmethod
    def validate_rut_syntax(cls, value: str) -> str:
        clean_val = value.strip()
        if not re.match(RUT_REGEX, clean_val):
            raise ValueError(
                "Sintaxis de RUT chileno inválida. Debe incluir guión y dígito verificador (ej: 76.452.189-4 o 76452189-4)"
            )
        return clean_val.upper()

class RUTValidateResponse(BaseModel):
    """
    Respuesta exitosa de validación de RUT.
    """
    rut: str = Field(..., description="RUT verificado")
    is_valid: bool = Field(..., description="Indica si el RUT es auténtico")
    message: str = Field(..., description="Detalle del resultado de validación")
