import asyncio
import logging
from sqlalchemy import select
from geoalchemy2.elements import WKTElement

from app.core.security import hash_password
from app.db.database import AsyncSessionLocal
from app.models.user import User
from app.models.foundation import Foundation
from app.models.animal import Animal

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("adoptify-seed")

# Contraseñas de las cuentas de prueba (solo para desarrollo local; ver README)
SEED_PASSWORDS = {
    "admin": "Admin2026",
    "adopter": "Adoptante2026",
    "foundation": "Fundacion2026",
}

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
                rut="11111111-1",
                hashed_password=hash_password(SEED_PASSWORDS["admin"]),
                full_name="Administrador Adoptify",
                phone="+56911223344",
                role="admin",
                preferences={}
            ),
            User(
                email="matias.adopter@gmail.com",
                rut="18765432-1",
                hashed_password=hash_password(SEED_PASSWORDS["adopter"]),
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
                rut="19876543-2",
                hashed_password=hash_password(SEED_PASSWORDS["adopter"]),
                full_name="Sofía Castro",
                phone="+56999887766",
                role="adopter",
                preferences={
                    "preferred_species": "gato",
                    "preferred_size": "pequeño",
                    "preferred_energy_level": 2,
                    "housing_type": "departamento"
                }
            ),
            User(
                email="fundacion@adoptify.cl",
                rut="20123456-3",
                hashed_password=hash_password(SEED_PASSWORDS["foundation"]),
                full_name="Garras y Patas",
                phone="+56922334455",
                role="foundation",
                preferences={}
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

        # Catálogo adicional solo para una base local nueva. Nunca ejecutar este seed contra Supabase.
        extra_foundations = [
            Foundation(name="Huellas del Sur", rut="76.500.101-1", email="hola@huellasdelsur.cl", phone="+56933001122", address="", commune="La Florida", city="Santiago", description="Rescatamos, rehabilitamos y buscamos hogares responsables.", is_verified=True, location=WKTElement("POINT(-70.5980 -33.5220)", srid=4326)),
            Foundation(name="Patitas de Cerro", rut="76.500.102-K", email="contacto@patitascerro.cl", phone="+56933001123", address="", commune="Valparaíso", city="Valparaíso", description="Red vecinal de rescate y adopción en la costa.", is_verified=True, location=WKTElement("POINT(-71.6127 -33.0472)", srid=4326)),
            Foundation(name="Bigotes Libres", rut="76.500.103-8", email="hola@bigoteslibres.cl", phone="+56933001124", address="", commune="Ñuñoa", city="Santiago", description="Especialistas en gatos que necesitan una segunda oportunidad.", is_verified=False, location=WKTElement("POINT(-70.5905 -33.4569)", srid=4326)),
            Foundation(name="Refugio El Arrayán", rut="76.500.104-6", email="equipo@elarrayan.cl", phone="+56933001125", address="", commune="Puente Alto", city="Santiago", description="Cuidado temporal y rehabilitación de perros mayores.", is_verified=True, location=WKTElement("POINT(-70.5770 -33.6117)", srid=4326)),
            Foundation(name="Rescate Horizonte", rut="76.500.105-4", email="hola@rescatehorizonte.cl", phone="+56933001126", address="", commune="Concepción", city="Concepción", description="Un equipo de voluntariado que acompaña rescates urgentes.", is_verified=False, location=WKTElement("POINT(-73.0503 -36.8270)", srid=4326)),
            Foundation(name="Casa Michi", rut="76.500.106-2", email="equipo@casamichi.cl", phone="+56933001127", address="", commune="Quilicura", city="Santiago", description="Hogar temporal para gatos rescatados y socialización felina.", is_verified=True, location=WKTElement("POINT(-70.7270 -33.3667)", srid=4326)),
        ]

        session.add_all([fundacion1, fundacion2, *extra_foundations])
        await session.flush()

        # La cuenta de fundación queda ligada a su fundación (HU-12)
        users[3].foundation_id = fundacion1.id

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
                location=WKTElement("POINT(-70.6189 -33.4312)", srid=4326),
                public_commune="Providencia"
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
                location=WKTElement("POINT(-70.6210 -33.4340)", srid=4326),
                public_commune="Providencia"
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
                location=WKTElement("POINT(-70.7578 -33.5112)", srid=4326),
                public_commune="Maipú"
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
                location=WKTElement("POINT(-70.7590 -33.5130)", srid=4326),
                public_commune="Maipú"
            )
        ]

        # Un caso visible por cada fundación adicional. Estos datos se crean solo en una BD local vacía.
        extra_animals = [
            ("Mora", "gato", 14, "pequeño", "La Florida", "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba"),
            ("Toto", "perro", 9, "pequeño", "Valparaíso", "https://images.unsplash.com/photo-1583511655857-d19b40a7a54e"),
            ("Nube", "gato", 6, "pequeño", "Ñuñoa", "https://images.unsplash.com/photo-1495360010541-f48722b34f7d"),
            ("Canela", "perro", 84, "mediano", "Puente Alto", "https://images.unsplash.com/photo-1587300003388-59208cc962cb"),
            ("Kira", "perro", 18, "mediano", "Concepción", "https://images.unsplash.com/photo-1537151608828-ea2b11777ee8"),
            ("Olivia", "gato", 20, "pequeño", "Quilicura", "https://images.unsplash.com/photo-1494256997604-768d1f608cac"),
        ]
        for foundation, (name, species, age_months, size, commune, photo_url) in zip(extra_foundations, extra_animals):
            point = foundation.location
            animals.append(Animal(
                foundation_id=foundation.id,
                name=name,
                species=species,
                breed="Mestizo",
                age_months=age_months,
                gender="hembra",
                size=size,
                energy_level=3,
                description="Caso de demostración para explorar la vitrina de adopción local.",
                status="available",
                photo_url=photo_url,
                tags={"vacunas": True, "esterilizado": True},
                location=point,
                public_commune=commune,
            ))

        session.add_all(animals)
        await session.commit()
        logger.info(f"Seed completado exitosamente: {len(users)} usuarios, {2 + len(extra_foundations)} fundaciones, {len(animals)} animales.")

if __name__ == "__main__":
    asyncio.run(seed_database())
