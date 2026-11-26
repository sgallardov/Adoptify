"""HU-Z: la app de usuario y el portal de fundaciones ven los mismos reportes.

Las dos vistas piden GET /reports/nearby con el criterio común (ver src/services/reportArea.ts en el
portal y reportSearchArea en features/map/map_service.dart de la app): con ubicación, el radio elegido
(10 km por defecto); sin ubicación, Santiago con 100 km. Estas pruebas comparan las dos llamadas.
"""

import random
import uuid

import pytest
from geoalchemy2.elements import WKTElement
from httpx import AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.foundation import Foundation
from app.models.report import AbandonedDogReport
from app.models.user import User

# Sede de la fundación de prueba, en Coyhaique: lejos del seed y de las demás pruebas de cercanía
SEDE = {"lat": -45.5712, "lng": -72.0685}
# Criterio común: con ubicación, el radio elegido; sin ubicación, Santiago con el radio máximo
DEFAULT_RADIUS_KM = 10
NO_LOCATION_AREA = {"lat": -33.4489, "lng": -70.6693, "radius_km": 100}


@pytest.fixture
async def shared_world(async_client: AsyncClient, db_session: AsyncSession):
    """Una fundación con sede, su cuenta y reportes a distancias conocidas de esa sede."""
    tag = uuid.uuid4().hex[:8]
    password = "ClaveSegura123"
    foundation = Foundation(
        name=f"Rescate Compartido {tag}",
        rut=f"{random.randint(30_000_000, 99_999_999)}-7",
        email=f"compartida_{tag}@test.cl",
        location=WKTElement(f"POINT({SEDE['lng']} {SEDE['lat']})", srid=4326),
    )
    db_session.add(foundation)
    await db_session.flush()
    user = User(
        email=f"fundacion_z_{tag}@test.cl",
        rut=f"{random.randint(30_000_000, 99_999_999)}-8",
        hashed_password=hash_password(password),
        full_name="Fundación Compartida",
        role="foundation",
        foundation_id=foundation.id,
    )

    def report(description: str, lat: float, status: str = "reported") -> AbandonedDogReport:
        return AbandonedDogReport(
            description=description, status=status,
            location=WKTElement(f"POINT({SEDE['lng']} {lat})", srid=4326),
        )

    reports = {
        # ~0,64 km de la sede: dentro del radio por defecto
        "cerca": report(f"HU-Z {tag} cerca", -45.5770),
        # ~36,6 km: fuera de los 10 km por defecto, dentro de 100 km
        "lejos": report(f"HU-Z {tag} lejos", -45.9000),
        # Cerca, pero resuelto: ninguna de las dos vistas lo muestra
        "resuelto": report(f"HU-Z {tag} resuelto", -45.5730, "resolved"),
    }
    db_session.add_all([user, *reports.values()])
    await db_session.commit()
    login = await async_client.post("/api/v1/auth/login", json={"email": user.email, "password": password})
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

    yield {"foundation": foundation, "headers": headers, "reports": reports, "tag": tag}

    await db_session.execute(delete(AbandonedDogReport).where(
        AbandonedDogReport.id.in_([item.id for item in reports.values()])
    ))
    await db_session.execute(delete(User).where(User.id == user.id))
    await db_session.execute(delete(Foundation).where(Foundation.id == foundation.id))
    await db_session.commit()


async def nearby(async_client: AsyncClient, area: dict, headers: dict | None = None) -> list[dict]:
    response = await async_client.get("/api/v1/reports/nearby", params=area, headers=headers or {})
    assert response.status_code == 200
    return response.json()


def ids_of(data: list[dict], tag: str) -> list[int]:
    """Solo los reportes de esta prueba, en el orden en que llegaron (del más cercano al más lejano)."""
    return [item["id"] for item in data if item["description"].startswith(f"HU-Z {tag}")]


async def test_la_sede_de_la_fundacion_es_el_mismo_origen_que_usa_la_app(async_client, shared_world):
    """El portal busca desde la sede que entrega /foundations/me: la misma ubicación que puede usar la app."""
    perfil = await async_client.get("/api/v1/foundations/me", headers=shared_world["headers"])
    assert perfil.status_code == 200
    assert perfil.json()["latitude"] == pytest.approx(SEDE["lat"])
    assert perfil.json()["longitude"] == pytest.approx(SEDE["lng"])


async def test_mismo_criterio_mismos_reportes_en_la_app_y_en_el_portal(async_client, shared_world):
    area = {**SEDE, "radius_km": DEFAULT_RADIUS_KM}
    tag = shared_world["tag"]
    # El portal consulta con la sesión de la fundación; la app, con la de la persona (o sin sesión)
    portal = await nearby(async_client, area, shared_world["headers"])
    app = await nearby(async_client, area)
    assert portal == app

    visibles = ids_of(portal, tag)
    assert visibles == [shared_world["reports"]["cerca"].id]
    # Ni el que está fuera del radio ni el resuelto aparecen en ninguna de las dos vistas
    assert shared_world["reports"]["lejos"].id not in visibles
    assert shared_world["reports"]["resuelto"].id not in visibles


async def test_con_un_radio_mayor_las_dos_vistas_suman_el_mismo_reporte(async_client, shared_world):
    area = {**SEDE, "radius_km": 100}
    portal = await nearby(async_client, area, shared_world["headers"])
    app = await nearby(async_client, area)
    assert portal == app
    assert ids_of(portal, shared_world["tag"]) == [
        shared_world["reports"]["cerca"].id,
        shared_world["reports"]["lejos"].id,
    ]


async def test_sin_ubicacion_las_dos_vistas_caen_en_santiago_con_cien_km(async_client, shared_world):
    """Una cuenta sin sede ubicada en el portal y la app sin permiso de ubicación piden lo mismo."""
    portal = await nearby(async_client, NO_LOCATION_AREA, shared_world["headers"])
    app = await nearby(async_client, NO_LOCATION_AREA)
    assert portal == app
    # Los reportes de esta prueba están en Coyhaique: a más de 100 km de Santiago, no salen en ninguna
    assert ids_of(portal, shared_world["tag"]) == []


async def test_el_estado_y_la_fundacion_que_tomo_el_caso_coinciden_en_las_dos_vistas(async_client, shared_world):
    area = {**SEDE, "radius_km": DEFAULT_RADIUS_KM}
    report_id = shared_world["reports"]["cerca"].id
    taken = await async_client.put(f"/api/v1/reports/{report_id}/taken", headers=shared_world["headers"])
    assert taken.status_code == 200

    def buscar(data: list[dict]) -> dict:
        return next(item for item in data if item["id"] == report_id)

    portal = buscar(await nearby(async_client, area, shared_world["headers"]))
    app = buscar(await nearby(async_client, area))
    assert portal == app
    assert portal["status"] == "in_rescue"
    assert portal["foundation_name"] == shared_world["foundation"].name
    assert portal["taken_by_foundation_id"] == shared_world["foundation"].id
    # Ninguna de las dos vistas expone quién reportó
    assert "reporter_id" not in portal
