"""Respuestas de error en español.

FastAPI y Pydantic responden en inglés ("Not authenticated", "String should have at least 2 characters").
Estos manejadores traducen esos mensajes sin cambiar la forma de la respuesta: un 422 sigue siendo
{"detail": [{"loc", "msg", "type"}]}, así el portal y la app siguen leyendo el campo con error.
El 422 tampoco devuelve lo que se envió ("input"), para no repetir contraseñas en la respuesta.
"""
from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

# Nombre legible de los campos más comunes; el resto se muestra con su nombre sin guiones bajos
FIELD_LABELS = {
    "full_name": "Nombre",
    "name": "Nombre",
    "email": "Correo",
    "password": "Contraseña",
    "current_password": "Contraseña actual",
    "new_password": "Nueva contraseña",
    "rut": "RUT",
    "code": "Código",
    "body": "Mensaje",
    "message": "Mensaje",
    "description": "Descripción",
    "phone": "Teléfono",
    "address": "Dirección",
    "commune": "Comuna",
    "latitude": "Ubicación",
    "longitude": "Ubicación",
    "lat": "Latitud",
    "lng": "Longitud",
    "radius_km": "Radio",
    "species": "Especie",
    "size": "Tamaño",
    "color": "Color",
    "status": "Estado",
    "photo_url": "Foto",
    "user_id": "Persona",
}

# Mensajes del framework que pueden llegar a un cliente
HTTP_DETAILS = {
    "Not authenticated": "Inicia sesión para continuar.",
    "Invalid authentication credentials": "Token inválido o expirado",
    "Not Found": "No encontrado.",
    "Method Not Allowed": "Método no permitido.",
    "Unsupported Media Type": "Tipo de contenido no permitido.",
}


def _label(loc: tuple) -> str | None:
    # loc es ("body", "full_name") o ("query", "lat"); el primer elemento indica dónde venía el dato
    field = next((part for part in reversed(loc) if isinstance(part, str) and part not in ("body", "query", "path", "header")), None)
    if field is None:
        return None
    return FIELD_LABELS.get(field, field.replace("_", " ").capitalize())


def _number(value) -> str:
    # 100.0 se muestra como 100 y 0.5 como 0,5 (coma decimal, como se escribe en Chile)
    if isinstance(value, float) and value.is_integer():
        value = int(value)
    return str(value).replace(".", ",")


def _options(expected: str) -> str:
    # Pydantic entrega "'perro', 'gato' or 'otro'"
    return expected.replace(" or ", " o ")


def _reason(error: dict) -> str:
    kind = error.get("type", "")
    ctx = error.get("ctx") or {}
    if kind == "missing":
        return "es obligatorio"
    if kind == "string_too_short":
        minimum = ctx.get("min_length", 1)
        return "no puede estar vacío" if minimum == 1 else f"debe tener al menos {minimum} caracteres"
    if kind == "string_too_long":
        return f"puede tener como máximo {ctx.get('max_length')} caracteres"
    if kind == "too_short":
        minimum = ctx.get("min_length", 1)
        return "debe tener al menos una opción" if minimum == 1 else f"debe tener al menos {minimum} opciones"
    if kind == "too_long":
        return f"puede tener como máximo {ctx.get('max_length')} opciones"
    if kind == "greater_than":
        return f"debe ser mayor que {_number(ctx.get('gt'))}"
    if kind == "greater_than_equal":
        return f"debe ser mayor o igual a {_number(ctx.get('ge'))}"
    if kind == "less_than":
        return f"debe ser menor que {_number(ctx.get('lt'))}"
    if kind == "less_than_equal":
        return f"debe ser menor o igual a {_number(ctx.get('le'))}"
    if kind in ("int_parsing", "int_type", "int_from_float"):
        return "debe ser un número entero"
    if kind in ("float_parsing", "float_type", "decimal_parsing", "decimal_type"):
        return "debe ser un número"
    if kind in ("bool_parsing", "bool_type"):
        return "debe ser sí o no"
    if kind == "string_type":
        return "debe ser un texto"
    if kind in ("list_type", "tuple_type", "set_type"):
        return "debe ser una lista"
    if kind in ("literal_error", "enum"):
        return f"debe ser una de estas opciones: {_options(str(ctx.get('expected', '')))}"
    if kind.startswith(("date", "datetime", "time")):
        return "debe ser una fecha válida"
    if kind.startswith("url"):
        return "debe ser un enlace válido"
    if kind == "extra_forbidden":
        return "no es un dato permitido"
    return "tiene un valor inválido"


def validation_message(error: dict) -> str:
    """Un error de Pydantic en una frase en español, para mostrarla tal cual al usuario."""
    kind = error.get("type", "")
    if kind == "json_invalid":
        return "Los datos enviados no tienen un formato válido."
    # Validadores propios: el texto ya está en español ("Value error, El nombre debe tener...")
    if kind in ("value_error", "assertion_error"):
        message = str(error.get("msg", ""))
        # El validador de correos (email-validator) responde en inglés
        if message.startswith("value is not a valid email address"):
            return f"{_label(tuple(error.get('loc', ()))) or 'Correo'}: no es un correo válido."
        for prefix in ("Value error, ", "Assertion failed, "):
            if message.startswith(prefix):
                return message[len(prefix):]
        return message
    reason = _reason(error)
    label = _label(tuple(error.get("loc", ())))
    return f"{label}: {reason}." if label else f"{reason[0].upper()}{reason[1:]}."


async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    detail = [
        {"loc": list(error.get("loc", ())), "msg": validation_message(error), "type": error.get("type")}
        for error in exc.errors()
    ]
    return JSONResponse(status_code=422, content={"detail": detail})


async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    detail = HTTP_DETAILS.get(exc.detail, exc.detail) if isinstance(exc.detail, str) else exc.detail
    return JSONResponse(status_code=exc.status_code, content={"detail": detail}, headers=getattr(exc, "headers", None))
