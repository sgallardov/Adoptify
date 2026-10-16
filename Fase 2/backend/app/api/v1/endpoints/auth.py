from fastapi import APIRouter, status, HTTPException
from app.schemas.auth import RUTValidateRequest, RUTValidateResponse
from app.services.auth_service import validate_rut_mock

router = APIRouter()

@router.post(
    "/validate-rut",
    response_model=RUTValidateResponse,
    status_code=status.HTTP_200_OK,
    summary="Validar autenticidad de RUT institucional (Mock)",
    description=(
        "Valida la sintaxis del RUT chileno mediante Regex en Pydantic. "
        "Aplica la regla de negocio Mock: retorna HTTP 200 si el RUT termina en dígito par, "
        "y HTTP 400 si termina en dígito impar o letra K."
    ),
    responses={
        200: {
            "description": "RUT auténtico y válido (dígito par)",
            "model": RUTValidateResponse
        },
        400: {
            "description": "RUT no autorizado o inválido (dígito impar o K)",
            "content": {
                "application/json": {
                    "example": {
                        "detail": {
                            "rut": "76.452.189-3",
                            "is_valid": False,
                            "message": "RUT 76.452.189-3 rechazado: el dígito verificador es impar (3)."
                        }
                    }
                }
            }
        },
        422: {
            "description": "Error de validación de sintaxis en el formato del RUT"
        }
    }
)
async def validate_foundation_rut(payload: RUTValidateRequest):
    is_valid, message = validate_rut_mock(payload.rut)

    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "rut": payload.rut,
                "is_valid": False,
                "message": message
            }
        )

    return RUTValidateResponse(
        rut=payload.rut,
        is_valid=True,
        message=message
    )
