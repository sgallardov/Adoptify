import random
import uuid

import httpx
import pytest
from httpx import AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.foundation import Foundation
from app.models.user import User
from app.services import geocoding

PASSWORD = "ClaveSegura123"
URL = "/api/v1/geocode"
NOMINATIM_ROWS = [
    {"display_name": "100, Avenida Grecia, Ñuñoa, Santiago, Chile", "lat": "-33.4569", "lon": "-70.6053"},
    {"display_name": "Sin coordenadas", "lat": None, "lon": None},
]


def unique_rut() -> str:
    return f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}"


@pytest.fixture
async def accounts(async_client: AsyncClient, db_session: AsyncSession):
    tag = uuid.uuid4().hex[:8]
    foundation = Foundation(name=f"Test Geo {tag}", rut=unique_rut(), email=f"test_geo_f_{tag}@adoptify.cl")
    db_session.add(foundation)
    await db_session.flush()
    users = {
        "foundation": User(email=f"test_geo_fund_{tag}@adoptify.cl", rut=unique_rut(), hashed_password=hash_password(PASSWORD),
                           full_name="Test Geo Fundación", role="foundation", foundation_id=foundation.id, preferences={}),
        "adopter": User(email=f"test_geo_adop_{tag}@adoptify.cl", rut=unique_rut(), hashed_password=hash_password(PASSWORD),
                        full_name="Test Geo Adoptante", role="adopter", preferences={}),
    }
    db_session.add_all(users.values())
    await db_session.commit()
    headers = {}
    for key, user in users.items():
        response = await async_client.post("/api/v1/auth/login", json={"email": user.email, "password": PASSWORD})
        headers[key] = {"Authorization": f"Bearer {response.json()['access_token']}"}
    yield headers
    await db_session.execute(delete(User).where(User.id.in_([u.id for u in users.values()])))
    await db_session.execute(delete(Foundation).where(Foundation.id == foundation.id))
    await db_session.commit()


@pytest.fixture
def fake_nominatim(monkeypatch):
    """Reemplaza la red por una respuesta fija y registra lo que se pidió a Nominatim."""
    calls: list[httpx.Request] = []
    state = {"status": 200}

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        return httpx.Response(state["status"], json=NOMINATIM_ROWS)

    real_client = httpx.AsyncClient
    monkeypatch.setattr(geocoding.httpx, "AsyncClient",
                        lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs))
    monkeypatch.setattr(geocoding, "_MIN_INTERVAL_SECONDS", 0)
    monkeypatch.setattr(geocoding, "_cache", {})
    return calls, state


async def test_foundation_finds_an_address_in_chile(async_client, accounts, fake_nominatim):
    calls, _ = fake_nominatim
    response = await async_client.get(URL, params={"q": "  Av. Grecia 100, Ñuñoa "}, headers=accounts["foundation"])

    assert response.status_code == 200
    # Se descartan los resultados sin coordenadas
    assert response.json() == [
        {"label": "100, Avenida Grecia, Ñuñoa, Santiago, Chile", "latitude": -33.4569, "longitude": -70.6053,
         "commune": "Ñuñoa"}
    ]
    sent = calls[0]
    assert sent.url.params["q"] == "Av. Grecia 100, Ñuñoa"
    assert sent.url.params["countrycodes"] == "cl"
    assert sent.headers["User-Agent"].startswith("Adoptify/")


async def test_repeated_search_uses_the_cache(async_client, accounts, fake_nominatim):
    calls, _ = fake_nominatim
    for query in ("Av. Grecia 100", "av. grecia 100"):
        assert (await async_client.get(URL, params={"q": query}, headers=accounts["foundation"])).status_code == 200
    assert len(calls) == 1


async def test_only_foundation_staff_can_search(async_client, accounts, fake_nominatim):
    assert (await async_client.get(URL, params={"q": "Ñuñoa"}, headers=accounts["adopter"])).status_code == 403
    assert (await async_client.get(URL, params={"q": "Ñuñoa"})).status_code == 401


async def test_validates_the_query(async_client, accounts, fake_nominatim):
    assert (await async_client.get(URL, params={"q": "ab"}, headers=accounts["foundation"])).status_code == 422
    assert (await async_client.get(URL, headers=accounts["foundation"])).status_code == 422


async def test_nominatim_failure_returns_503(async_client, accounts, fake_nominatim):
    _, state = fake_nominatim
    state["status"] = 502
    response = await async_client.get(URL, params={"q": "Ñuñoa"}, headers=accounts["foundation"])
    assert response.status_code == 503
    assert response.json()["detail"] == "No pudimos buscar la dirección. Inténtalo en unos segundos."


@pytest.mark.parametrize("label, commune", [
    # Se reconoce aunque OpenStreetMap la escriba sin tilde o en mayúsculas
    ("Calle Uno, Puerto Aysen, AYSEN, Provincia de Aysén, Chile", "Aysén"),
    ("Plaza de Armas, Santiago, Provincia de Santiago, Chile", "Santiago"),
    # La primera parte es la calle: "Recoleta" ahí no cuenta como comuna
    ("Recoleta, Barrio Bellavista, Providencia, Santiago, Chile", "Providencia"),
    ("Ruta 5, Sin comuna conocida, Chile", None),
])
def test_commune_is_recognized_from_the_place(label, commune):
    assert geocoding._commune_of(label) == commune
