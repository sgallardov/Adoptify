"""Importa las clínicas veterinarias de OpenStreetMap (amenity=veterinary) a veterinary_clinics.

Uso (desde Fase 2/):
    docker compose exec backend python -m app.db.import_vet_clinics --allow-shared

Es idempotente: cada clínica se identifica por su osm_id ("node/123", "way/456"), así que volver a
correrlo actualiza los datos sin duplicar. Por defecto trae la Región Metropolitana; --region cambia
la región (nombre de la región administrativa en OpenStreetMap). Los datos son © colaboradores de
OpenStreetMap (licencia ODbL): el mapa de la app ya muestra la atribución.
"""

import argparse
import asyncio

import httpx
from geoalchemy2.elements import WKTElement
from sqlalchemy.dialects.postgresql import insert

from app.core.config import settings
from app.db.database import AsyncSessionLocal
from app.models.veterinary_clinic import VeterinaryClinic

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
QUERY = """
[out:json][timeout:90];
area["boundary"="administrative"]["admin_level"="4"]["name"~"{region}"]->.region;
nwr["amenity"="veterinary"](area.region);
out center tags;
"""


def clinic_from_osm(element: dict) -> dict | None:
    """Convierte un elemento de Overpass en los datos de una clínica. Sin nombre o sin ubicación, None."""
    tags = element.get("tags", {})
    name = (tags.get("name") or "").strip()
    # Los nodos traen lat/lon; los edificios (way) traen su centro en "center"
    point = element if "lat" in element else element.get("center")
    if not name or not point:
        return None

    street = tags.get("addr:street")
    number = tags.get("addr:housenumber")
    address = f"{street} {number}" if street and number else street
    hours = tags.get("opening_hours")
    return {
        "osm_id": f"{element['type']}/{element['id']}",
        "name": name[:255],
        "address": address[:255] if address else None,
        "commune": (tags.get("addr:city") or tags.get("addr:suburb") or None),
        "phone": (tags.get("phone") or tags.get("contact:phone") or None),
        "opening_hours": hours[:255] if hours else None,
        "emergency": tags.get("emergency") == "yes" or hours == "24/7",
        "location": WKTElement(f"POINT({point['lon']} {point['lat']})", srid=4326),
    }


async def fetch_clinics(region: str) -> list[dict]:
    async with httpx.AsyncClient(timeout=120, headers={"User-Agent": "Adoptify/1.0 (proyecto Capstone Duoc UC)"}) as client:
        response = await client.post(OVERPASS_URL, data={"data": QUERY.format(region=region)})
        response.raise_for_status()
    clinics = [clinic_from_osm(element) for element in response.json()["elements"]]
    return [clinic for clinic in clinics if clinic is not None]


async def import_clinics(region: str, allow_shared: bool) -> tuple[int, int]:
    if settings.DATABASE_URL and not allow_shared:
        raise SystemExit("DATABASE_URL apunta a la BD compartida: usa --allow-shared para importar ahí.")
    clinics = await fetch_clinics(region)
    async with AsyncSessionLocal() as session:
        for clinic in clinics:
            statement = insert(VeterinaryClinic).values(**clinic)
            await session.execute(
                statement.on_conflict_do_update(
                    index_elements=[VeterinaryClinic.osm_id],
                    set_={key: statement.excluded[key] for key in clinic if key != "osm_id"},
                )
            )
        await session.commit()
    return len(clinics), sum(1 for clinic in clinics if clinic["emergency"])


def main() -> None:
    parser = argparse.ArgumentParser(description="Importa clínicas veterinarias desde OpenStreetMap.")
    parser.add_argument("--region", default="Metropolitana", help="nombre (o parte) de la región en OpenStreetMap")
    parser.add_argument("--allow-shared", action="store_true", help="autoriza escribir en la BD compartida")
    args = parser.parse_args()
    total, emergency = asyncio.run(import_clinics(args.region, args.allow_shared))
    print(f"Clínicas veterinarias importadas o actualizadas: {total} ({emergency} de urgencias o 24 horas).")


if __name__ == "__main__":
    main()
