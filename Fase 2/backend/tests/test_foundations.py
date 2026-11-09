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
    assert not {"latitude", "longitude", "distance_km"}.intersection(found["animals"][0])
    assert found["animals"][0]["commune_point"] is None
    assert found["animals"][0]["foundation_name"] == foundation_with_animals.name


async def test_no_expone_rut_ni_geometria(async_client: AsyncClient, foundation_with_animals):
    response = await async_client.get("/api/v1/foundations")

    found = next(item for item in response.json() if item["id"] == foundation_with_animals.id)
    assert "rut" not in found
    assert "location" not in found


async def test_ordena_por_nombre(async_client: AsyncClient, foundation_with_animals):
    data = (await async_client.get("/api/v1/foundations")).json()
    names = [item["name"] for item in data]
    assert names == sorted(names)
    assert all(item["distance_km"] is None for item in data)


async def test_ordena_por_cercania(async_client: AsyncClient, foundation_with_animals):
    # Desde Ñuñoa la fundación de prueba queda a 0 km y es la primera
    data = (await async_client.get("/api/v1/foundations", params={"lat": -33.45, "lng": -70.6})).json()

    assert data[0]["id"] == foundation_with_animals.id
    assert data[0]["distance_km"] == pytest.approx(0)
    distances = [item["distance_km"] for item in data]
    measured = [d for d in distances if d is not None]
    assert measured == sorted(measured)
    # Las fundaciones sin ubicación van al final
    assert distances == measured + [None] * (len(distances) - len(measured))


async def test_distancia_en_km(async_client: AsyncClient, foundation_with_animals):
    # Valparaíso queda a unos 100 km de Ñuñoa
    data = (await async_client.get("/api/v1/foundations", params={"lat": -33.0472, "lng": -71.6127})).json()

    found = next(item for item in data if item["id"] == foundation_with_animals.id)
    assert 95 < found["distance_km"] < 110


async def test_cercania_exige_lat_y_lng(async_client: AsyncClient):
    response = await async_client.get("/api/v1/foundations", params={"lat": -33.45})

    assert response.status_code == 422
    assert response.json()["detail"] == "Para ordenar por cercanía envía lat y lng juntos."
