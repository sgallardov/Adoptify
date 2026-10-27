import pytest
from geoalchemy2.elements import WKTElement
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.animal import Animal
from app.models.foundation import Foundation

# Punto de búsqueda en Punta Arenas: lejos de los animales del seed (Santiago) para no mezclar resultados
ORIGIN = {"lat": -53.1638, "lng": -70.9171}


def animal(foundation_id: int, name: str, lat: float, status: str = "available") -> Animal:
    return Animal(
        foundation_id=foundation_id, name=name, species="perro", gender="macho", size="mediano",
        energy_level=3, status=status, location=WKTElement(f"POINT({ORIGIN['lng']} {lat})", srid=4326),
    )


@pytest.fixture
async def nearby_animals(db_session: AsyncSession):
    """Una fundación con animales a distancias conocidas al norte/sur del punto de búsqueda."""
    foundation = Foundation(name="Fundación Austral Test", rut="77.777.777-7", email="austral_test@adoptify.cl", city="Punta Arenas")
    db_session.add(foundation)
    await db_session.flush()
    db_session.add_all([
        animal(foundation.id, "Cerca", -53.1700),            # ~0,69 km
        animal(foundation.id, "Medio", -53.2000),            # ~4,03 km
        animal(foundation.id, "Lejos", -53.5000),            # ~37,4 km
        animal(foundation.id, "Adoptado", -53.1650, "adopted"),  # cerca, pero no disponible
    ])
    await db_session.commit()
    yield foundation
    await db_session.delete(foundation)  # Cascade elimina los animales
    await db_session.commit()


def names(data: list[dict], foundation_id: int) -> list[str]:
    return [a["name"] for a in data if a["foundation_id"] == foundation_id]


class TestNearbyAnimals:
    """
    Búsqueda por cercanía con PostGIS (GET /api/v1/animals/nearby).
    """

    async def test_returns_available_animals_within_radius_sorted_by_distance(self, async_client: AsyncClient, nearby_animals):
        response = await async_client.get("/api/v1/animals/nearby", params={**ORIGIN, "radius_km": 10})

        assert response.status_code == 200
        data = response.json()
        assert names(data, nearby_animals.id) == ["Cerca", "Medio"]
        distances = {a["name"]: a["distance_km"] for a in data}
        assert distances["Cerca"] == pytest.approx(0.69, abs=0.05)
        assert distances["Medio"] == pytest.approx(4.03, abs=0.05)

    async def test_larger_radius_includes_farther_animals(self, async_client: AsyncClient, nearby_animals):
        response = await async_client.get("/api/v1/animals/nearby", params={**ORIGIN, "radius_km": 50})

        assert names(response.json(), nearby_animals.id) == ["Cerca", "Medio", "Lejos"]

    async def test_response_includes_coordinates_and_foundation_name(self, async_client: AsyncClient, nearby_animals):
        response = await async_client.get("/api/v1/animals/nearby", params={**ORIGIN, "radius_km": 1})

        cerca = response.json()[0]
        assert cerca["name"] == "Cerca"
        assert cerca["latitude"] == pytest.approx(-53.17)
        assert cerca["longitude"] == pytest.approx(ORIGIN["lng"])
        assert cerca["foundation_name"] == "Fundación Austral Test"

    async def test_animal_list_includes_coordinates(self, async_client: AsyncClient, nearby_animals):
        response = await async_client.get("/api/v1/animals")

        lejos = next(a for a in response.json() if a["name"] == "Lejos" and a["foundation_id"] == nearby_animals.id)
        assert lejos["latitude"] == pytest.approx(-53.5)
        assert lejos["longitude"] == pytest.approx(ORIGIN["lng"])
        assert lejos["foundation_name"] == "Fundación Austral Test"
        assert "location" not in lejos

    @pytest.mark.parametrize("params", [
        {"lng": -70.9},                                    # falta lat
        {"lat": 100, "lng": -70.9},                        # latitud fuera de rango
        {"lat": -53.1, "lng": -200},                       # longitud fuera de rango
        {"lat": -53.1, "lng": -70.9, "radius_km": 0},      # radio debe ser mayor que 0
        {"lat": -53.1, "lng": -70.9, "radius_km": 101},    # radio máximo 100 km
    ])
    async def test_invalid_parameters_return_422(self, async_client: AsyncClient, params: dict):
        response = await async_client.get("/api/v1/animals/nearby", params=params)

        assert response.status_code == 422
