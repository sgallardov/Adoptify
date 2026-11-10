import random
import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.foundation import Foundation
from app.models.foundation_member import FoundationMember
from app.models.user import User

PASSWORD = "ClaveSegura123"
URL = "/api/v1/foundations/me/members"


def public_url(foundation_id: int) -> str:
    return f"/api/v1/foundations/{foundation_id}/members/public"


@pytest.fixture
async def setup(async_client: AsyncClient, db_session: AsyncSession):
    """Dos fundaciones con su cuenta cada una, un adoptante y un admin, con encabezados de sesión."""
    suffix = uuid.uuid4().hex[:8]

    def foundation(label: str) -> Foundation:
        return Foundation(
            name=f"Fundación Socios {label} {suffix}",
            rut=f"{random.randint(60_000_000, 99_999_999)}-{random.choice('0123456789K')}",
            email=f"socios_{label}_{suffix}@adoptify.cl",
        )

    foundations = {"a": foundation("a"), "b": foundation("b")}
    db_session.add_all(foundations.values())
    await db_session.flush()

    def user(label: str, role: str, foundation_id: int | None = None) -> User:
        return User(
            email=f"test_socios_{label}_{suffix}@adoptify.cl",
            rut=f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}",
            hashed_password=hash_password(PASSWORD), full_name=f"Test {label}", role=role,
            foundation_id=foundation_id, preferences={},
        )

    users = {
        "a": user("a", "foundation", foundations["a"].id),
        "b": user("b", "foundation", foundations["b"].id),
        "adopter": user("adop", "adopter"),
        "admin": user("admin", "admin"),
    }
    db_session.add_all(users.values())
    await db_session.commit()

    headers = {}
    for key, account in users.items():
        response = await async_client.post("/api/v1/auth/login", json={"email": account.email, "password": PASSWORD})
        headers[key] = {"Authorization": f"Bearer {response.json()['access_token']}"}
    yield {"foundations": foundations, "headers": headers}

    ids = [f.id for f in foundations.values()]
    await db_session.execute(delete(FoundationMember).where(FoundationMember.foundation_id.in_(ids)))
    await db_session.execute(delete(User).where(User.id.in_([u.id for u in users.values()])))
    await db_session.execute(delete(Foundation).where(Foundation.id.in_(ids)))
    await db_session.commit()


def body(name: str = "Ana Pérez", **extra) -> dict:
    return {"name": name, "contribution": "15000.50", "joined_at": "2026-03-15", "is_public": False, **extra}


async def test_fundacion_crea_lista_edita_y_borra_sus_socios(async_client: AsyncClient, setup):
    headers = setup["headers"]["a"]

    created = await async_client.post(URL, json=body(), headers=headers)
    assert created.status_code == 201
    member = created.json()
    assert member["foundation_id"] == setup["foundations"]["a"].id
    assert member["contribution"] == "15000.50"
    assert member["is_public"] is False

    listed = await async_client.get(URL, headers=headers)
    assert [m["id"] for m in listed.json()] == [member["id"]]

    edited = await async_client.put(
        f"{URL}/{member['id']}", json=body("Ana P. Soto", contribution=None, is_public=True), headers=headers
    )
    assert edited.status_code == 200
    assert edited.json()["name"] == "Ana P. Soto"
    assert edited.json()["contribution"] is None
    assert edited.json()["is_public"] is True

    assert (await async_client.delete(f"{URL}/{member['id']}", headers=headers)).status_code == 204
    assert (await async_client.get(URL, headers=headers)).json() == []


async def test_foundation_id_del_cuerpo_se_ignora_para_fundaciones(async_client: AsyncClient, setup):
    response = await async_client.post(
        URL, json=body(foundation_id=setup["foundations"]["b"].id), headers=setup["headers"]["a"]
    )

    assert response.json()["foundation_id"] == setup["foundations"]["a"].id


async def test_otra_fundacion_recibe_403_al_editar_o_borrar(async_client: AsyncClient, setup):
    member = (await async_client.post(URL, json=body(), headers=setup["headers"]["a"])).json()
    intruder = setup["headers"]["b"]

    edit = await async_client.put(f"{URL}/{member['id']}", json=body("Hackeado"), headers=intruder)
    delete_ = await async_client.delete(f"{URL}/{member['id']}", headers=intruder)

    assert edit.status_code == 403
    assert delete_.status_code == 403
    # Nada cambió y la otra fundación no lo ve en su listado
    still = (await async_client.get(URL, headers=setup["headers"]["a"])).json()
    assert [m["name"] for m in still] == ["Ana Pérez"]
    assert (await async_client.get(URL, headers=intruder)).json() == []


async def test_sin_sesion_o_sin_ser_fundacion(async_client: AsyncClient, setup):
    assert (await async_client.get(URL)).status_code == 401
    for verb, kwargs in (("get", {}), ("post", {"json": body()})):
        response = await getattr(async_client, verb)(URL, headers=setup["headers"]["adopter"], **kwargs)
        assert response.status_code == 403


async def test_admin_ve_todo_y_crea_indicando_fundacion(async_client: AsyncClient, setup):
    admin = setup["headers"]["admin"]
    await async_client.post(URL, json=body("De A"), headers=setup["headers"]["a"])

    sin_fundacion = await async_client.post(URL, json=body("Sin fundación"), headers=admin)
    assert sin_fundacion.status_code == 422

    creado = await async_client.post(
        URL, json=body("De B", foundation_id=setup["foundations"]["b"].id), headers=admin
    )
    assert creado.status_code == 201

    ids = {setup["foundations"]["a"].id, setup["foundations"]["b"].id}
    todos = [m for m in (await async_client.get(URL, headers=admin)).json() if m["foundation_id"] in ids]
    assert {m["name"] for m in todos} == {"De A", "De B"}
    solo_b = (await async_client.get(URL, params={"foundation_id": setup["foundations"]["b"].id}, headers=admin)).json()
    assert [m["name"] for m in solo_b] == ["De B"]


@pytest.mark.parametrize(
    "changes",
    [{"name": "   "}, {"name": ""}, {"contribution": "-1"}, {"joined_at": "no-es-fecha"}],
)
async def test_valida_los_datos(async_client: AsyncClient, setup, changes):
    response = await async_client.post(URL, json={**body(), **changes}, headers=setup["headers"]["a"])

    assert response.status_code == 422


async def test_publico_solo_muestra_socios_marcados_y_nunca_el_aporte(async_client: AsyncClient, setup):
    headers = setup["headers"]["a"]
    await async_client.post(URL, json=body("Pública", is_public=True), headers=headers)
    await async_client.post(URL, json=body("Privada", is_public=False), headers=headers)

    # Sin sesión
    response = await async_client.get(public_url(setup["foundations"]["a"].id))

    assert response.status_code == 200
    assert response.json() == [{"name": "Pública", "joined_at": "2026-03-15"}]
    assert "15000" not in response.text
    assert "contribution" not in response.text


async def test_publico_no_mezcla_fundaciones(async_client: AsyncClient, setup):
    await async_client.post(URL, json=body("Solo de B", is_public=True), headers=setup["headers"]["b"])

    response = await async_client.get(public_url(setup["foundations"]["a"].id))

    assert response.json() == []


async def test_estado_vacio(async_client: AsyncClient, setup):
    assert (await async_client.get(URL, headers=setup["headers"]["a"])).json() == []
    response = await async_client.get(public_url(setup["foundations"]["a"].id))
    assert response.status_code == 200
    assert response.json() == []


async def test_socio_inexistente_da_404(async_client: AsyncClient, setup):
    response = await async_client.delete(f"{URL}/999999999", headers=setup["headers"]["a"])

    assert response.status_code == 404
