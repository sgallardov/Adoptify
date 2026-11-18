"""Referencias públicas ADM3 de Chile de GeoNames (CC BY 4.0).
Fuente: https://download.geonames.org/export/dump/CL.zip
Los nombres están corregidos a la escritura oficial (ver commune_renames.py).
Solo se usan puntos del catálogo, nunca coordenadas derivadas de un animal.
"""
import json
import unicodedata
from pathlib import Path

COMMUNES = json.loads(Path(__file__).with_name("communes.json").read_text(encoding="utf-8"))


def _fold(text: str) -> str:
    """Sin tildes, eñes, diéresis, apóstrofos ni mayúsculas: "Aysén", "AYSEN" y "aysen" son iguales."""
    decomposed = unicodedata.normalize("NFD", text)
    plain = "".join(char for char in decomposed if unicodedata.category(char) != "Mn")
    return " ".join(plain.replace("'", " ").casefold().split())


_BY_FOLDED = {_fold(name): name for name in COMMUNES}


def find_commune(text: str | None) -> str | None:
    """Nombre del catálogo que corresponde al texto, o None si no es una comuna conocida."""
    return _BY_FOLDED.get(_fold(text)) if text else None
