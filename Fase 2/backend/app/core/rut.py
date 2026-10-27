import re

# Formato de RUT chileno: con puntos (12.345.678-5) o sin ellos (12345678-5); el dígito final es 0-9 o K
RUT_REGEX = re.compile(r"^(\d{1,2}(?:\.\d{3}){2}|\d{7,8})-[\dkK]$")


def normalize_rut(value: str) -> str:
    """
    Revisa solo el formato del RUT (no calcula el dígito verificador) y lo devuelve
    en una forma única: sin puntos y con K mayúscula. Así 12.345.678-5 y 12345678-5
    se guardan igual y no pueden repetirse entre usuarios.
    """
    clean = value.strip()
    if not RUT_REGEX.match(clean):
        raise ValueError("Formato de RUT inválido. Usa 12.345.678-5 o 12345678-5")
    return clean.replace(".", "").upper()
