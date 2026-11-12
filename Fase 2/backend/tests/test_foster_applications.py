import random
import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.foster_application import FosterApplication
from app.models.user import User

PASSWORD = "ClaveSegura123"
URL = "/api/v1/foster-applications"
VALID = {
    "species": "ambos",
    "sizes": ["pequeño", "mediano"],
    "space": "casa_patio",
    "max_animals": 2,
    "max_days": 30,
    "availability": "Desde ya, todos los días",
    "phone": "+56 9 1234 5678",
    "address": "Av. Grecia 1234, Ñuñoa",
}


@pytest.fixture
async def accounts(async_client: AsyncClient, db_session: AsyncSession):
    """Un adoptante y una cuenta de fundación con su sesión; se borran al terminar (con su postulación)."""
    tag = uuid.uuid4().hex[:8]

    def user(label: str, role: str) -> User:
        return User(
            email=f"test_hogar_{label}_{tag}@adoptify.cl",
            rut=f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}",
            hashed_password=hash_password(PASSWORD), full_name=f"Test {label}", role=role, preferences={},
        )

    users = {"adopter": user("adop", "adopter"), "foundation": user("fund", "foundation")}
    db_session.add_all(users.values())
    await db_session.commit()

    headers = {}
    for key, account in users.items():
        response = await async_client.post("/api/v1/auth/login", json={"email": account.email, "password": PASSWORD})
        headers[key] = {"Authorization": f"Bearer {response.json()['access_token']}"}
    yield {"users": users, "headers": headers}

    ids = [u.id for u in users.values()]
    await db_session.execute(delete(FosterApplication).where(FosterApplication.user_id.in_(ids)))
    await db_session.execute(delete(User).where(User.id.in_(ids)))
    await db_session.commit()


async def test_sin_postulacion_devuelve_null(async_client: AsyncClient, accounts):
    response = await async_client.get(f"{URL}/me", headers=accounts["headers"]["adopter"])

    assert response.status_code == 200
    assert response.json() is None


async def test_adoptante_postula_sin_elegir_fundacion(async_client: AsyncClient, accounts):
    headers = accounts["headers"]["adopter"]
    response = await async_client.post(URL, json=VALID, headers=headers)

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "pending"
    assert body["address"] == "Av. Grecia 1234, Ñuñoa"
    assert body["max_animals"] == 2 and body["max_days"] == 30
    assert "foundation_id" not in body
    # Queda guardada y se puede consultar
    assert (await async_client.get(f"{URL}/me", headers=headers)).json()["id"] == body["id"]


@pytest.mark.parametrize("field", list(VALID))
async def test_todos_los_campos_son_obligatorios(async_client: AsyncClient, accounts, field):
    body = {key: value for key, value in VALID.items() if key != field}

    response = await async_client.post(URL, json=body, headers=accounts["headers"]["adopter"])

    assert response.status_code == 422


@pytest.mark.parametrize(
    "change",
    [
        {"species": "conejo"},
        {"sizes": []},
        {"sizes": ["gigante"]},
        {"space": "parcela"},
        {"max_animals": 0},
        {"max_days": 400},
        {"availability": "   "},
        {"phone": "123"},
        {"address": "abc"},
    ],
)
async def test_rechaza_valores_invalidos(async_client: AsyncClient, accounts, change):
    response = await async_client.post(URL, json={**VALID, **change}, headers=accounts["headers"]["adopter"])

    assert response.status_code == 422


async def test_una_sola_postulacion_por_cuenta(async_client: AsyncClient, accounts):
    headers = accounts["headers"]["adopter"]
    await async_client.post(URL, json=VALID, headers=headers)

    again = await async_client.post(URL, json=VALID, headers=headers)

    assert again.status_code == 409


async def test_solo_adoptantes_postulan(async_client: AsyncClient, accounts):
    response = await async_client.post(URL, json=VALID, headers=accounts["headers"]["foundation"])

    assert response.status_code == 403
    assert (await async_client.post(URL, json=VALID)).status_code == 401


async def test_edita_mientras_esta_pendiente(async_client: AsyncClient, accounts):
    headers = accounts["headers"]["adopter"]
    await async_client.post(URL, json=VALID, headers=headers)

    response = await async_client.put(f"{URL}/me", json={**VALID, "max_days": 60, "species": "gato"}, headers=headers)

    assert response.status_code == 200
    assert response.json()["max_days"] == 60
    assert response.json()["species"] == "gato"


async def test_no_edita_una_postulacion_ya_revisada(async_client: AsyncClient, db_session: AsyncSession, accounts):
    headers = accounts["headers"]["adopter"]
    created = (await async_client.post(URL, json=VALID, headers=headers)).json()
    application = await db_session.get(FosterApplication, created["id"])
    application.status = "approved"
    await db_session.commit()

    response = await async_client.put(f"{URL}/me", json=VALID, headers=headers)

    assert response.status_code == 409
    assert "ya fue revisada" in response.json()["detail"]


async def test_retirar_la_postulacion(async_client: AsyncClient, accounts):
    headers = accounts["headers"]["adopter"]
    await async_client.post(URL, json=VALID, headers=headers)

    assert (await async_client.delete(f"{URL}/me", headers=headers)).status_code == 204
    assert (await async_client.get(f"{URL}/me", headers=headers)).json() is None
    # Después de retirarla puede volver a postular
    assert (await async_client.post(URL, json=VALID, headers=headers)).status_code == 201


async def test_editar_o_retirar_sin_postulacion(async_client: AsyncClient, accounts):
    headers = accounts["headers"]["adopter"]

    assert (await async_client.put(f"{URL}/me", json=VALID, headers=headers)).status_code == 404
    assert (await async_client.delete(f"{URL}/me", headers=headers)).status_code == 404
