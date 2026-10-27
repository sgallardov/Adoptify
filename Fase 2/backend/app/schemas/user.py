from typing import Annotated, Literal

from pydantic import AfterValidator, BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.core.rut import normalize_rut

# Tipo de cuenta que se elige en la pestaña del login
AccountType = Literal["user", "foundation"]

# bcrypt solo admite contraseñas de hasta 72 bytes (una "ñ" o una tilde ocupan 2)
MAX_PASSWORD_BYTES = 72


def normalize_email(value: str) -> str:
    """Los correos se guardan y comparan en minúsculas: Prueba@x.cl y prueba@x.cl son la misma cuenta."""
    return value.strip().lower()


NormalizedEmail = Annotated[EmailStr, AfterValidator(normalize_email)]
NormalizedRut = Annotated[str, AfterValidator(normalize_rut)]


class UserCreate(BaseModel):
    """
    Datos para registrar un nuevo usuario.
    """
    email: NormalizedEmail = Field(..., examples=["adoptante@adoptify.cl"])
    rut: NormalizedRut = Field(..., description="RUT con o sin puntos; se guarda como 12345678-5", examples=["12.345.678-5"])
    password: str = Field(..., min_length=8, description="Mínimo 8 caracteres y máximo 72 bytes")
    full_name: str = Field(..., min_length=2, max_length=255)

    @field_validator("password")
    @classmethod
    def validate_password_bytes(cls, value: str) -> str:
        if len(value.encode("utf-8")) > MAX_PASSWORD_BYTES:
            raise ValueError("La contraseña es demasiado larga (máximo 72 bytes; las letras con tilde o ñ cuentan doble)")
        return value

    @field_validator("full_name")
    @classmethod
    def validate_full_name(cls, value: str) -> str:
        clean = value.strip()
        if len(clean) < 2:
            raise ValueError("El nombre debe tener al menos 2 caracteres")
        return clean


class UserPublic(BaseModel):
    """
    Datos de un usuario que se pueden devolver al cliente (nunca incluye la contraseña).
    """
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    rut: str
    full_name: str
    role: str


class LoginRequest(BaseModel):
    """
    Credenciales para iniciar sesión.
    """
    email: NormalizedEmail
    password: str
    account_type: AccountType = Field("user", description="'user' para adoptantes, 'foundation' para fundaciones")


class TokenResponse(BaseModel):
    """
    Token de acceso que el cliente envía en el header Authorization: Bearer <token>.
    """
    access_token: str
    token_type: str = "bearer"
    role: str
