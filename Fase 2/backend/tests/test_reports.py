import random
import uuid

import pytest
from geoalchemy2.elements import WKTElement
from httpx import AsyncClient
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.report import AbandonedDogReport
from app.models.user import User

# Punto de búsqueda en Coyhaique: lejos de los datos del seed y de las pruebas de animales cercanos
ORIGIN = {"lat": -45.5712, "lng": -72.0685}


@pytest.fixture
async def auth_headers(async_client: AsyncClient, db_session: AsyncSession):
    """Registra un usuario, inicia sesión y elimina al usuario (y sus reportes) al terminar."""
    email = f"reporte_{uuid.uuid4().hex[:10]}@adoptify.cl"
    rut = f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}"
    await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "rut": rut, "password": "ClaveSegura123", "full_name": "Usuario Reporte"},
    )
    login = await async_client.post("/api/v1/auth/login", json={"email": email, "password": "ClaveSegura123"})
    yield {"Authorization": f"Bearer {login.json()['access_token']}"}

    user_id = (await db_session.execute(select(User.id).where(User.email == email))).scalar_one()
    await db_session.execute(delete(AbandonedDogReport).where(AbandonedDogReport.reporter_id == user_id))
    await db_session.execute(delete(User).where(User.id == user_id))
    await db_session.commit()


@pytest.fixture
async def nearby_reports(db_session: AsyncSession):
    """Reportes a distancias conocidas al sur del punto de búsqueda."""
    def report(description: str, lat: float, status: str = "reported") -> AbandonedDogReport:
        return AbandonedDogReport(
            description=description, status=status,
            location=WKTElement(f"POINT({ORIGIN['lng']} {lat})", srid=4326),
        )

    reports = [
        report("Test cercano", -45.5770),               # ~0,64 km
        report("Test medio", -45.6100),                 # ~4,31 km
        report("Test lejos", -45.9000),                 # ~36,6 km
        report("Test resuelto", -45.5730, "resolved"),  # cerca, pero ya resuelto
    ]
    db_session.add_all(reports)
    await db_session.commit()
    yield reports
    for item in reports:
        await db_session.delete(item)
    await db_session.commit()


def descriptions(data: list[dict]) -> list[str]:
    return [r["description"] for r in data if r["description"].startswith("Test ")]


class TestCreateReport:
    """
    Creación de reportes de perros abandonados (POST /api/v1/reports).
    """

    async def test_logged_in_user_creates_report(self, async_client: AsyncClient, auth_headers: dict):
        response = await async_client.post(
            "/api/v1/reports",
            json={"latitude": -45.58, "longitude": -72.07, "description": "Perro café con collar rojo, parece herido"},
            headers=auth_headers,
        )

        assert response.status_code == 201
        data = response.json()
        assert data["status"] == "reported"
        assert data["latitude"] == pytest.approx(-45.58)
        assert data["longitude"] == pytest.approx(-72.07)
        assert "reporter_id" not in data
        assert "location" not in data

    async def test_report_without_session_returns_401_or_403(self, async_client: AsyncClient):
        response = await async_client.post(
            "/api/v1/reports",
            json={"latitude": -45.58, "longitude": -72.07, "description": "Perro café con collar rojo"},
        )

        assert response.status_code in (401, 403)

    @pytest.mark.parametrize("payload", [
        {"latitude": 100, "longitude": -72.07, "description": "Latitud fuera de rango"},
        {"latitude": -45.58, "longitude": -200, "description": "Longitud fuera de rango"},
        {"latitude": -45.58, "longitude": -72.07, "description": "Corta"},
        {"longitude": -72.07, "description": "Falta la latitud del perro"},
    ])
    async def test_invalid_report_returns_422(self, async_client: AsyncClient, auth_headers: dict, payload: dict):
        response = await async_client.post("/api/v1/reports", json=payload, headers=auth_headers)

        assert response.status_code == 422


class TestNearbyReports:
    """
    Búsqueda de reportes por cercanía con PostGIS (GET /api/v1/reports/nearby).
    """

    async def test_returns_active_reports_within_radius_sorted_by_distance(self, async_client: AsyncClient, nearby_reports):
        response = await async_client.get("/api/v1/reports/nearby", params={**ORIGIN, "radius_km": 10})

        assert response.status_code == 200
        data = response.json()
        assert descriptions(data) == ["Test cercano", "Test medio"]
        distances = {r["description"]: r["distance_km"] for r in data}
        assert distances["Test cercano"] == pytest.approx(0.64, abs=0.05)
        assert distances["Test medio"] == pytest.approx(4.31, abs=0.05)

    async def test_larger_radius_includes_farther_reports(self, async_client: AsyncClient, nearby_reports):
        response = await async_client.get("/api/v1/reports/nearby", params={**ORIGIN, "radius_km": 50})

        assert descriptions(response.json()) == ["Test cercano", "Test medio", "Test lejos"]

    async def test_nearby_does_not_require_session(self, async_client: AsyncClient, nearby_reports):
        response = await async_client.get("/api/v1/reports/nearby", params={**ORIGIN, "radius_km": 1})

        assert response.status_code == 200
        assert descriptions(response.json()) == ["Test cercano"]

    @pytest.mark.parametrize("params", [
        {"lng": -72.0},                                    # falta lat
        {"lat": 100, "lng": -72.0},                        # latitud fuera de rango
        {"lat": -45.5, "lng": -72.0, "radius_km": 0},      # radio debe ser mayor que 0
        {"lat": -45.5, "lng": -72.0, "radius_km": 101},    # radio máximo 100 km
    ])
    async def test_invalid_parameters_return_422(self, async_client: AsyncClient, params: dict):
        response = await async_client.get("/api/v1/reports/nearby", params=params)

        assert response.status_code == 422
