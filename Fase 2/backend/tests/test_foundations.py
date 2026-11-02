import random
import uuid

import pytest
from geoalchemy2.elements import WKTElement
from httpx import AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.animal import Animal
from app.models.foundation import Foundation


@pytest.fixture
async def foundation_with_animals(db_session: AsyncSession):
    """Fundación de prueba con un animal disponible, uno en proceso y uno adoptado; se elimina al terminar."""
    suffix = uuid.uuid4().hex[:8]
    foundation = Foundation(
        name=f"Fundación Prueba {suffix}",
        rut=f"{random.randint(60_000_000, 99_999_999)}-{random.choice('0123456789K')}",
        email=f"fundacion_{suffix}@adoptify.cl",
        phone="+56 9 1234 5678",
        commune="Ñuñoa",
        description="Rescatamos perros y gatos.",
        location=WKTElement("POINT(-70.6 -33.45)", srid=4326),
    )
    db_session.add(foundation)
    await db_session.flush()

    def animal(name: str, status: str) -> Animal:
        return Animal(
            foundation_id=foundation.id, name=name, species="perro", gender="macho",
            size="mediano", energy_level=3, status=status,
        )

    db_session.add_all([animal("Disponible", "available"), animal("En proceso", "in_process"), animal("Adoptado", "adopted")])
    await db_session.commit()
    yield foundation

    await db_session.execute(delete(Animal).where(Animal.foundation_id == foundation.id))
    await db_session.execute(delete(Foundation).where(Foundation.id == foundation.id))
    await db_session.commit()


async def test_lista_fundaciones_con_solo_sus_animales_disponibles(async_client: AsyncClient, foundation_with_animals):
    response = await async_client.get("/api/v1/foundations")

    assert response.status_code == 200
    found = next(item for item in response.json() if item["id"] == foundation_with_animals.id)
    assert found["name"] == foundation_with_animals.name
    assert found["commune"] == "Ñuñoa"
    assert found["phone"] == "+56 9 1234 5678"
    assert found["latitude"] == pytest.approx(-33.45)
    assert found["longitude"] == pytest.approx(-70.6)
    assert [animal["name"] for animal in found["animals"]] == ["Disponible"]
    assert found["animals"][0]["foundation_name"] == foundation_with_animals.name


async def test_no_expone_rut_ni_geometria(async_client: AsyncClient, foundation_with_animals):
    response = await async_client.get("/api/v1/foundations")

    found = next(item for item in response.json() if item["id"] == foundation_with_animals.id)
    assert "rut" not in found
    assert "location" not in found


async def test_ordena_por_nombre(async_client: AsyncClient, foundation_with_animals):
    names = [item["name"] for item in (await async_client.get("/api/v1/foundations")).json()]
    assert names == sorted(names)
