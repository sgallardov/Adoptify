import uuid

import pytest
from geoalchemy2.elements import WKTElement
from httpx import AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.import_vet_clinics import clinic_from_osm
from app.models.veterinary_clinic import VeterinaryClinic


@pytest.fixture
async def clinics(db_session: AsyncSession):
    """Una clínica de urgencias y una normal; se eliminan al terminar."""
    tag = uuid.uuid4().hex[:8]
    items = [
        VeterinaryClinic(
            osm_id=f"node/test-{tag}-1", name=f"Test Clínica Normal {tag}", address="Av. Grecia 100",
            commune="Ñuñoa", emergency=False, location=WKTElement("POINT(-70.60 -33.46)", srid=4326),
        ),
        VeterinaryClinic(
            osm_id=f"node/test-{tag}-2", name=f"Test Clínica Urgencias {tag}", phone="+56 2 2222 3333",
            opening_hours="24/7", emergency=True, location=WKTElement("POINT(-70.61 -33.43)", srid=4326),
        ),
    ]
    db_session.add_all(items)
    await db_session.commit()
    yield items

    await db_session.execute(delete(VeterinaryClinic).where(VeterinaryClinic.id.in_([c.id for c in items])))
    await db_session.commit()


async def test_lista_publica_con_coordenadas(async_client: AsyncClient, clinics):
    response = await async_client.get("/api/v1/veterinary-clinics")

    assert response.status_code == 200
    found = next(item for item in response.json() if item["id"] == clinics[0].id)
    assert found["name"] == clinics[0].name
    assert found["commune"] == "Ñuñoa"
    assert found["latitude"] == pytest.approx(-33.46)
    assert found["longitude"] == pytest.approx(-70.60)
    assert "location" not in found and "osm_id" not in found


async def test_urgencias_primero(async_client: AsyncClient, clinics):
    data = (await async_client.get("/api/v1/veterinary-clinics")).json()

    flags = [item["emergency"] for item in data]
    assert flags == sorted(flags, reverse=True)
    ids = [item["id"] for item in data]
    assert ids.index(clinics[1].id) < ids.index(clinics[0].id)


def test_convierte_nodo_de_openstreetmap():
    clinic = clinic_from_osm({
        "type": "node", "id": 42, "lat": -33.42, "lon": -70.57,
        "tags": {
            "name": "Veterinaria Kennedy", "addr:street": "Las Tranqueras", "addr:housenumber": "1200",
            "addr:city": "Vitacura", "phone": "+56 2 2345 6789", "opening_hours": "24/7",
        },
    })

    assert clinic["osm_id"] == "node/42"
    assert clinic["address"] == "Las Tranqueras 1200"
    assert clinic["commune"] == "Vitacura"
    assert clinic["phone"] == "+56 2 2345 6789"
    assert clinic["emergency"] is True
    assert clinic["location"].data == "POINT(-70.57 -33.42)"


def test_convierte_edificio_con_su_centro():
    clinic = clinic_from_osm({
        "type": "way", "id": 7, "center": {"lat": -33.5, "lon": -70.7},
        "tags": {"name": "Clinopet", "addr:street": "Apoquindo", "emergency": "yes"},
    })

    assert clinic["osm_id"] == "way/7"
    assert clinic["address"] == "Apoquindo"
    assert clinic["commune"] is None
    assert clinic["emergency"] is True
    assert clinic["location"].data == "POINT(-70.7 -33.5)"


@pytest.mark.parametrize("element", [
    {"type": "node", "id": 1, "lat": -33.4, "lon": -70.6, "tags": {}},
    {"type": "node", "id": 2, "lat": -33.4, "lon": -70.6, "tags": {"name": "   "}},
    {"type": "way", "id": 3, "tags": {"name": "Sin ubicación"}},
])
def test_descarta_sin_nombre_o_sin_ubicacion(element):
    assert clinic_from_osm(element) is None
