import pytest
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from geoalchemy2.elements import WKTElement

from app.models.user import User
from app.models.foundation import Foundation
from app.models.animal import Animal

class TestDataModelsHU04:
    """
    Pruebas automatizadas para los Criterios de Aceptación de HU-04 (Modelamiento de Datos).
    Verifica creación de tablas, restricciones de unicidad, relaciones FK y soporte PostGIS en Animal.
    """

    async def test_user_creation_and_preferences(self, db_session: AsyncSession):
        """Verifica la persistencia y lectura de usuarios con preferencias JSON."""
        test_user = User(
            email="test_model_user@adoptify.cl",
            rut="29999999-9",
            hashed_password="secure_hashed_password",
            full_name="Usuario de Prueba",
            role="adopter",
            preferences={"preferred_species": "perro", "preferred_energy_level": 3}
        )
        db_session.add(test_user)
        await db_session.commit()

        # Consultar usuario
        result = await db_session.execute(
            select(User).where(User.email == "test_model_user@adoptify.cl")
        )
        saved_user = result.scalar_one()
        assert saved_user.id is not None
        assert saved_user.role == "adopter"
        assert saved_user.rut == "29999999-9"
        assert saved_user.preferences["preferred_species"] == "perro"

        # Limpiar
        await db_session.delete(saved_user)
        await db_session.commit()

    async def test_foundation_creation_and_rut(self, db_session: AsyncSession):
        """Verifica la persistencia de una fundación con RUT y ubicación."""
        foundation = Foundation(
            name="Fundación Test Valdivia",
            rut="65.987.321-1",
            email="test_valdivia@adoptify.cl",
            phone="+56911223344",
            commune="Valdivia",
            city="Valdivia",
            is_verified=True,
            location=WKTElement("POINT(-73.2459 -39.8142)", srid=4326)
        )
        db_session.add(foundation)
        await db_session.commit()

        res = await db_session.execute(
            select(Foundation).where(Foundation.rut == "65.987.321-1")
        )
        saved_foundation = res.scalar_one()
        assert saved_foundation.name == "Fundación Test Valdivia"
        assert saved_foundation.rut == "65.987.321-1"

        # Limpiar
        await db_session.delete(saved_foundation)
        await db_session.commit()

    async def test_animal_postgis_location_and_query(self, db_session: AsyncSession):
        """
        Criterio HU-04:
        El campo location de Animal debe ser de tipo Geometry('POINT', srid=4326) usando GeoAlchemy2.
        """
        # Crear fundación para asociar el animal
        f = Foundation(
            name="Fundación Temporal PostGIS",
            rut="99.888.777-6",
            email="temp_geo@adoptify.cl",
            city="Santiago"
        )
        db_session.add(f)
        await db_session.flush()

        # Crear animal con punto GPS (-70.6483 longitud, -33.4569 latitud)
        animal = Animal(
            foundation_id=f.id,
            name="Max PostGIS",
            species="perro",
            gender="macho",
            size="grande",
            energy_level=5,
            status="available",
            location=WKTElement("POINT(-70.6483 -33.4569)", srid=4326)
        )
        db_session.add(animal)
        await db_session.commit()

        # Consultar y verificar el campo espacial con función PostGIS ST_AsText
        query = select(
            Animal.name,
            func.ST_AsText(Animal.location).label("geom_text")
        ).where(Animal.id == animal.id)

        res = await db_session.execute(query)
        row = res.one()

        assert row.name == "Max PostGIS"
        assert "POINT(-70.6483 -33.4569)" in row.geom_text

        # Limpiar
        await db_session.delete(f)  # Cascade elimina el animal
        await db_session.commit()

    async def test_fk_relationship_and_cascade_delete(self, db_session: AsyncSession):
        """
        Criterio HU-04:
        Relaciones FK funcionando y eliminación en cascada.
        """
        f = Foundation(
            name="Fundación Para Cascada",
            rut="55.444.333-2",
            email="cascade_test@adoptify.cl",
            city="Santiago"
        )
        db_session.add(f)
        await db_session.flush()

        animal = Animal(
            foundation_id=f.id,
            name="Perrito Cascada",
            species="perro",
            gender="hembra",
            size="pequeño",
            energy_level=2,
            status="available"
        )
        db_session.add(animal)
        await db_session.commit()
        animal_id = animal.id

        # Verificar relación bidireccional
        await db_session.refresh(f)
        assert len(f.animals) >= 1
        assert f.animals[0].name == "Perrito Cascada"

        # Eliminar la fundación y verificar que el animal se elimina en cascada
        await db_session.delete(f)
        await db_session.commit()

        check_animal = await db_session.execute(
            select(Animal).where(Animal.id == animal_id)
        )
        assert check_animal.scalar_one_or_none() is None
