import random
import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.foster_application import FosterApplication
from app.models.foundation import Foundation
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


# --- Parte 2: vista de las fundaciones ---

@pytest.fixture
async def foundations_world(async_client: AsyncClient, db_session: AsyncSession):
    """Dos fundaciones con su cuenta, un adoptante con su postulación y un admin; se borran al terminar."""
    tag = uuid.uuid4().hex[:8]
    foundations = [
        Foundation(name=f"Test Hogar {n} {tag}", rut=f"{random.randint(60_000_000, 99_999_999)}-{n}",
                   email=f"test_hogar_f{n}_{tag}@adoptify.cl")
        for n in ("1", "2")
    ]
    db_session.add_all(foundations)
    await db_session.flush()

    def user(label: str, role: str, foundation_id: int | None = None) -> User:
        return User(
            email=f"test_hogar_{label}_{tag}@adoptify.cl",
            rut=f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}",
            hashed_password=hash_password(PASSWORD), full_name=f"Test {label}", role=role,
            foundation_id=foundation_id, preferences={},
        )

    users = {
        "adopter": user("postulante", "adopter"),
        "a": user("fa", "foundation", foundations[0].id),
        "b": user("fb", "foundation", foundations[1].id),
        "admin": user("admin", "admin"),
    }
    db_session.add_all(users.values())
    await db_session.commit()

    headers = {}
    for key, account in users.items():
        response = await async_client.post("/api/v1/auth/login", json={"email": account.email, "password": PASSWORD})
        headers[key] = {"Authorization": f"Bearer {response.json()['access_token']}"}
    application = (await async_client.post(URL, json=VALID, headers=headers["adopter"])).json()
    yield {"users": users, "foundations": foundations, "headers": headers, "application": application}

    ids = [u.id for u in users.values()]
    await db_session.execute(delete(FosterApplication).where(FosterApplication.user_id.in_(ids)))
    await db_session.execute(delete(User).where(User.id.in_(ids)))
    await db_session.execute(delete(Foundation).where(Foundation.id.in_([f.id for f in foundations])))
    await db_session.commit()


def find_application(items: list[dict], application_id: int) -> dict:
    return next(item for item in items if item["id"] == application_id)


async def test_la_fundacion_ve_el_contacto_completo(async_client: AsyncClient, foundations_world):
    world = foundations_world
    response = await async_client.get(URL, headers=world["headers"]["a"])

    assert response.status_code == 200
    item = find_application(response.json(), world["application"]["id"])
    assert item["full_name"] == "Test postulante"
    assert item["email"] == world["users"]["adopter"].email
    assert item["address"] == "Av. Grecia 1234, Ñuñoa"
    assert item["phone"] == "+56 9 1234 5678"
    assert item["status"] == "pending"
    assert item["can_decide"] is True


async def test_un_adoptante_no_ve_las_postulaciones(async_client: AsyncClient, foundations_world):
    response = await async_client.get(URL, headers=foundations_world["headers"]["adopter"])

    assert response.status_code == 403
    assert (await async_client.get(URL)).status_code == 401


async def test_aprobar_se_ve_en_el_listado_de_todas(async_client: AsyncClient, foundations_world):
    world = foundations_world
    app_id = world["application"]["id"]

    approved = await async_client.patch(f"{URL}/{app_id}", json={"status": "approved"}, headers=world["headers"]["a"])

    assert approved.status_code == 200
    assert approved.json()["status"] == "approved"
    assert approved.json()["decided_by_foundation_name"] == world["foundations"][0].name
    # Estado global: la otra fundación la ve aprobada, pero no puede decidir
    item = find_application((await async_client.get(URL, headers=world["headers"]["b"])).json(), app_id)
    assert item["status"] == "approved"
    assert item["can_decide"] is False
    # Y el adoptante ve su postulación aprobada
    mine = await async_client.get(f"{URL}/me", headers=world["headers"]["adopter"])
    assert mine.json()["status"] == "approved"


async def test_solo_la_fundacion_que_decidio_puede_cambiarla(async_client: AsyncClient, foundations_world):
    world = foundations_world
    url = f"{URL}/{world['application']['id']}"
    await async_client.patch(url, json={"status": "rejected"}, headers=world["headers"]["a"])

    other = await async_client.patch(url, json={"status": "approved"}, headers=world["headers"]["b"])
    assert other.status_code == 403
    assert world["foundations"][0].name in other.json()["detail"]

    # La que decidió puede corregirse y volverla a pendiente; ahí cualquier fundación decide de nuevo
    back = await async_client.patch(url, json={"status": "pending"}, headers=world["headers"]["a"])
    assert back.json()["status"] == "pending"
    assert back.json()["decided_by_foundation_name"] is None
    assert (await async_client.patch(url, json={"status": "approved"}, headers=world["headers"]["b"])).status_code == 200


async def test_filtra_por_estado_y_ordena_pendientes_primero(async_client: AsyncClient, foundations_world):
    world = foundations_world
    app_id = world["application"]["id"]
    await async_client.patch(f"{URL}/{app_id}", json={"status": "approved"}, headers=world["headers"]["a"])

    pending = (await async_client.get(URL, params={"status": "pending"}, headers=world["headers"]["a"])).json()
    approved = (await async_client.get(URL, params={"status": "approved"}, headers=world["headers"]["a"])).json()
    assert app_id not in [item["id"] for item in pending]
    assert app_id in [item["id"] for item in approved]

    statuses = [item["status"] for item in (await async_client.get(URL, headers=world["headers"]["a"])).json()]
    assert statuses == sorted(statuses, key=lambda s: s != "pending")


async def test_solo_fundaciones_vinculadas_deciden(async_client: AsyncClient, foundations_world):
    world = foundations_world
    url = f"{URL}/{world['application']['id']}"

    assert (await async_client.patch(url, json={"status": "approved"}, headers=world["headers"]["adopter"])).status_code == 403
    assert (await async_client.patch(url, json={"status": "approved"}, headers=world["headers"]["admin"])).status_code == 403
    assert (await async_client.patch(url, json={"status": "aceptada"}, headers=world["headers"]["a"])).status_code == 422


async def test_decidir_una_postulacion_retirada(async_client: AsyncClient, foundations_world):
    world = foundations_world
    await async_client.delete(f"{URL}/me", headers=world["headers"]["adopter"])

    response = await async_client.patch(
        f"{URL}/{world['application']['id']}", json={"status": "approved"}, headers=world["headers"]["a"]
    )

    assert response.status_code == 404
