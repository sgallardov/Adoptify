"""Carga idempotente de fundaciones y animales demostrativos.

No crea migraciones ni borra datos. Para evitar escribir por accidente en una
base compartida exige el flag explícito ``--allow-shared`` cuando DATABASE_URL
está configurada.
"""

import argparse
import asyncio

from geoalchemy2.elements import WKTElement
from sqlalchemy import select

from app.core.config import settings
from app.db.database import AsyncSessionLocal
from app.models.animal import Animal
from app.models.foundation import Foundation


DEMO_FOUNDATIONS = [
    {
        "name": "Huellas del Sur",
        "rut": "76.500.101-1",
        "email": "demo.huellas-sur@adoptify.cl",
        "phone": "+56933001122",
        "commune": "La Florida",
        "city": "Santiago",
        "description": "Rescatamos, rehabilitamos y buscamos hogares responsables.",
        "verified": True,
        "point": "POINT(-70.5980 -33.5220)",
        "animals": [
            ("Mora", "gato", 14, "pequeño", "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba"),
            ("Bruno", "perro", 30, "grande", "https://images.unsplash.com/photo-1558788353-f76d92427f16"),
        ],
    },
    {
        "name": "Patitas de Cerro",
        "rut": "76.500.102-K",
        "email": "demo.patitas-cerro@adoptify.cl",
        "phone": "+56933001123",
        "commune": "Valparaíso",
        "city": "Valparaíso",
        "description": "Red vecinal de rescate y adopción en la costa.",
        "verified": True,
        "point": "POINT(-71.6127 -33.0472)",
        "animals": [
            ("Toto", "perro", 9, "pequeño", "https://images.unsplash.com/photo-1583511655857-d19b40a7a54e"),
            ("Cali", "gato", 26, "mediano", "https://images.unsplash.com/photo-1518791841217-8f162f1e1131"),
        ],
    },
    {
        "name": "Bigotes Libres",
        "rut": "76.500.103-8",
        "email": "demo.bigotes-libres@adoptify.cl",
        "phone": "+56933001124",
        "commune": "Ñuñoa",
        "city": "Santiago",
        "description": "Especialistas en gatos que necesitan una segunda oportunidad.",
        "verified": False,
        "point": "POINT(-70.5905 -33.4569)",
        "animals": [
            ("Nube", "gato", 6, "pequeño", "https://images.unsplash.com/photo-1495360010541-f48722b34f7d"),
            ("Simón", "gato", 36, "mediano", "https://images.unsplash.com/photo-1494256997604-768d1f608cac"),
        ],
    },
    {
        "name": "Refugio El Arrayán",
        "rut": "76.500.104-6",
        "email": "demo.el-arrayan@adoptify.cl",
        "phone": "+56933001125",
        "commune": "Puente Alto",
        "city": "Santiago",
        "description": "Cuidado temporal y rehabilitación de perros mayores.",
        "verified": True,
        "point": "POINT(-70.5770 -33.6117)",
        "animals": [
            ("Canela", "perro", 84, "mediano", "https://images.unsplash.com/photo-1587300003388-59208cc962cb"),
            ("Dante", "perro", 42, "grande", "https://images.unsplash.com/photo-1537151608828-ea2b11777ee8"),
        ],
    },
    {
        "name": "Rescate Horizonte",
        "rut": "76.500.105-4",
        "email": "demo.rescate-horizonte@adoptify.cl",
        "phone": "+56933001126",
        "commune": "Concepción",
        "city": "Concepción",
        "description": "Un equipo de voluntariado que acompaña rescates urgentes.",
        "verified": False,
        "point": "POINT(-73.0503 -36.8270)",
        "animals": [
            ("Kira", "perro", 18, "mediano", "https://images.unsplash.com/photo-1543466835-00a7907e9de1"),
        ],
    },
    {
        "name": "Casa Michi",
        "rut": "76.500.106-2",
        "email": "demo.casa-michi@adoptify.cl",
        "phone": "+56933001127",
        "commune": "Quilicura",
        "city": "Santiago",
        "description": "Hogar temporal para gatos rescatados y socialización felina.",
        "verified": True,
        "point": "POINT(-70.7270 -33.3667)",
        "animals": [
            ("Olivia", "gato", 20, "pequeño", "https://images.unsplash.com/photo-1494256997604-768d1f608cac"),
            ("Miel", "gato", 11, "pequeño", "https://images.unsplash.com/photo-1513360371669-4adf3dd7dff8"),
        ],
    },
]


async def seed_demo_foundations(allow_shared: bool) -> tuple[int, int]:
    if settings.uses_shared_db and not allow_shared:
        raise RuntimeError("La BD compartida requiere --allow-shared para insertar datos demo.")

    created_foundations = 0
    created_animals = 0
    async with AsyncSessionLocal() as session:
        for item in DEMO_FOUNDATIONS:
            result = await session.execute(select(Foundation).where(Foundation.email == item["email"]))
            foundation = result.scalar_one_or_none()
            if foundation is None:
                foundation = Foundation(
                    name=item["name"],
                    rut=item["rut"],
                    email=item["email"],
                    phone=item["phone"],
                    address=None,
                    commune=item["commune"],
                    city=item["city"],
                    description=item["description"],
                    is_verified=item["verified"],
                    location=WKTElement(item["point"], srid=4326),
                )
                session.add(foundation)
                await session.flush()
                created_foundations += 1

            for name, species, age_months, size, photo_url in item["animals"]:
                existing = await session.execute(
                    select(Animal).where(Animal.foundation_id == foundation.id, Animal.name == name)
                )
                if existing.scalar_one_or_none() is not None:
                    continue
                session.add(
                    Animal(
                        foundation_id=foundation.id,
                        public_commune=item["commune"],
                        name=name,
                        species=species,
                        breed="Mestizo",
                        age_months=age_months,
                        gender="hembra" if species == "gato" else "macho",
                        size=size,
                        energy_level=3,
                        description="Caso demostrativo disponible para adopción responsable.",
                        status="available",
                        photo_url=photo_url,
                        tags={"demo": True, "vacunas": True, "esterilizado": True},
                        location=WKTElement(item["point"], srid=4326),
                    )
                )
                created_animals += 1
        await session.commit()
    return created_foundations, created_animals


def main() -> None:
    parser = argparse.ArgumentParser(description="Carga fundaciones demo de forma idempotente.")
    parser.add_argument("--allow-shared", action="store_true", help="autoriza insertar en la BD compartida")
    args = parser.parse_args()
    foundations, animals = asyncio.run(seed_demo_foundations(args.allow_shared))
    print(f"Datos demo listos: {foundations} fundaciones y {animals} animales creados.")


if __name__ == "__main__":
    main()
