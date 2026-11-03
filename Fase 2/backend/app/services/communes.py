"""Referencias públicas ADM3 de Chile de GeoNames (CC BY 4.0).
Fuente: https://download.geonames.org/export/dump/CL.zip
Solo se usan puntos del catálogo, nunca coordenadas derivadas de un animal.
"""
import json
from pathlib import Path

COMMUNES = json.loads(Path(__file__).with_name("communes.json").read_text(encoding="utf-8"))
