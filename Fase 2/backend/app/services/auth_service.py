from typing import Tuple

def validate_rut_mock(rut: str) -> Tuple[bool, str]:
    """
    Lógica Mock para validación de autenticidad de RUT institucional (HU-03).
    
    Regla de negocio definida en el requerimiento:
    - Retorna True si el RUT termina en un número par (0, 2, 4, 6, 8).
    - Retorna False si el RUT termina en un número impar (1, 3, 5, 7, 9) o letra 'K'.
    """
    clean_rut = rut.strip().upper()
    last_char = clean_rut[-1]

    if last_char.isdigit():
        digit = int(last_char)
        if digit % 2 == 0:
            return True, f"RUT {clean_rut} autenticado correctamente ante el registro de fundaciones (Mock: dígito par {digit})."
        else:
            return False, f"RUT {clean_rut} rechazado: el dígito verificador es impar ({digit})."
    elif last_char == "K":
        return False, f"RUT {clean_rut} rechazado: el dígito verificador es 'K' (no corresponde a un dígito par)."
    else:
        return False, f"RUT {clean_rut} inválido: el carácter final '{last_char}' no es válido."
