import asyncio
import logging
from sqlalchemy import select
from geoalchemy2.elements import WKTElement

from app.db.database import AsyncSessionLocal
from app.models.user import User
from app.models.foundation import Foundation
from app.models.animal import Animal

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("adoptify-seed")

async def seed_database():
    """
    Puebla la base de datos con datos de prueba realistas para desarrollo local y pruebas de match.
    """
    async with AsyncSessionLocal() as session:
        # 1. Comprobar si ya existen fundaciones registradas
        res = await session.execute(select(Foundation).limit(1))
        if res.scalar_one_or_none():
            logger.info("La base de datos ya contiene datos. Saltando seeder.")
            return

        logger.info("Iniciando carga de datos de prueba (Seed)...")

        # 2. Crear Usuarios de prueba
        users = [
            User(
                email="admin@adoptify.cl",
                hashed_password="hashed_admin_password_123",
                full_name="Administrador Adoptify",
                phone="+56911223344",
                role="admin",
                preferences={}
            ),
            User(
                email="matias.adopter@gmail.com",
                hashed_password="hashed_user_password_123",
                full_name="Matías Morales",
                phone="+56955667788",
                role="adopter",
                preferences={
                    "preferred_species": "perro",
                    "preferred_size": "mediano",
                    "preferred_energy_level": 4,
                    "housing_type": "casa_con_patio"
                }
            ),
            User(
                email="sofia.adopter@gmail.com",
                hashed_password="hashed_user_password_123",
                full_name="Sofía Castro",
                phone="+56999887766",
                role="adopter",
                preferences={
                    "preferred_species": "gato",
                    "preferred_size": "pequeño",
                    "preferred_energy_level": 2,
                    "housing_type": "departamento"
                }
            )
        ]
        session.add_all(users)
        await session.flush()

        # 3. Crear Fundaciones de prueba (con coordenadas en Santiago)
        fundacion1 = Foundation(
            name="Fundación Garras y Patas",
            rut="76.452.189-3",
            email="contacto@garrasypatas.cl",
            phone="+56922334455",
            address="Av. Providencia 1234",
            commune="Providencia",
            city="Santiago",
            description="Organización dedicada al rescate, rehabilitación y adopción responsable en la RM.",
            is_verified=True,
            location=WKTElement("POINT(-70.6189 -33.4312)", srid=4326)
        )

        fundacion2 = Foundation(
            name="Refugio San Francisco",
            rut="77.102.348-K",
            email="contacto@refugiosanfrancisco.cl",
            phone="+56988776655",
            address="Camino a Rinconada 567",
            commune="Maipú",
            city="Santiago",
            description="Refugio enfocado en rescate de perros de gran tamaño y rehabilitación médica.",
            is_verified=True,
            location=WKTElement("POINT(-70.7578 -33.5112)", srid=4326)
        )

        session.add_all([fundacion1, fundacion2])
        await session.flush()

        # 4. Crear Animales de prueba vinculados a las fundaciones
        animals = [
            Animal(
                foundation_id=fundacion1.id,
                name="Rocky",
                species="perro",
                breed="Mestizo",
                age_months=18,
                gender="macho",
                size="mediano",
                energy_level=4,
                description="Perro muy activo, juguetón y amigable con otros perros. Requiere paseos diarios.",
                status="available",
                photo_url="https://images.unsplash.com/photo-1543466835-00a7907e9de1",
                tags={"vacunas": True, "esterilizado": True, "apto_ninos": True},
                location=WKTElement("POINT(-70.6189 -33.4312)", srid=4326)
            ),
            Animal(
                foundation_id=fundacion1.id,
                name="Luna",
                species="gato",
                breed="Común Europeo",
                age_months=10,
                gender="hembra",
                size="pequeño",
                energy_level=2,
                description="Gatita tranquila, regalona y acostumbrada a vivir en departamento.",
                status="available",
                photo_url="https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba",
                tags={"vacunas": True, "esterilizado": True, "apto_departamento": True},
                location=WKTElement("POINT(-70.6210 -33.4340)", srid=4326)
            ),
            Animal(
                foundation_id=fundacion2.id,
                name="Thor",
                species="perro",
                breed="Mestizo Pastor",
                age_months=24,
                gender="macho",
                size="grande",
                energy_level=5,
                description="Perro guardián y protector, ideal para casas grandes o parcelas.",
                status="available",
                photo_url="https://images.unsplash.com/photo-1589941013453-ec89f33b5455",
                tags={"vacunas": True, "esterilizado": True, "necesita_patio": True},
                location=WKTElement("POINT(-70.7578 -33.5112)", srid=4326)
            ),
            Animal(
                foundation_id=fundacion2.id,
                name="Milo",
                species="perro",
                breed="Poodle Mestizo",
                age_months=8,
                gender="macho",
                size="pequeño",
                energy_level=3,
                description="Cachorro muy cariñoso, sociable y de bajo nivel de muda.",
                status="available",
                photo_url="https://images.unsplash.com/photo-1583511655857-d19b40a7a54e",
                tags={"vacunas": True, "esterilizado": False, "sociable": True},
                location=WKTElement("POINT(-70.7590 -33.5130)", srid=4326)
            )
        ]

        session.add_all(animals)
        await session.commit()
        logger.info(f"Seed completado exitosamente: {len(users)} usuarios, 2 fundaciones, {len(animals)} animales.")

if __name__ == "__main__":
    asyncio.run(seed_database())
