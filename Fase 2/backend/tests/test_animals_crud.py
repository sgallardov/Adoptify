import random
import uuid

import pytest
from geoalchemy2.elements import WKTElement
from httpx import AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.animal import Animal
from app.models.foundation import Foundation
from app.models.user import User

PASSWORD = "ClaveSegura123"
NEW_ANIMAL = {
    "name": "Test Nuevo",
    "species": "perro",
    "gender": "macho",
    "size": "mediano",
    "energy_level": 4,
    "latitude": -45.5712,
    "longitude": -72.0685,
}


def unique_rut() -> str:
    return f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}"


async def login_headers(client: AsyncClient, email: str, account_type: str) -> dict:
    response = await client.post(
        "/api/v1/auth/login", json={"email": email, "password": PASSWORD, "account_type": account_type}
    )
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


@pytest.fixture
async def world(async_client: AsyncClient, db_session: AsyncSession):
    """Dos fundaciones con una cuenta y un animal cada una, más un administrador y un adoptante."""
    tag = uuid.uuid4().hex[:8]
    foundations = [
        Foundation(name=f"Test Fundación {n}", rut=unique_rut(), email=f"test_f{n}_{tag}@adoptify.cl")
        for n in ("A", "B")
    ]
    db_session.add_all(foundations)
    await db_session.flush()

    def user(label: str, role: str, foundation_id: int | None = None) -> User:
        return User(
            email=f"test_{label}_{tag}@adoptify.cl", rut=unique_rut(), hashed_password=hash_password(PASSWORD),
            full_name=f"Test {label}", role=role, foundation_id=foundation_id, preferences={},
        )

    users = {
        "a": user("a", "foundation", foundations[0].id),
        "b": user("b", "foundation", foundations[1].id),
        "sin_fundacion": user("sinf", "foundation"),
        "admin": user("admin", "admin"),
        "adopter": user("adopter", "adopter"),
    }
    db_session.add_all(users.values())
    animals = [
        Animal(
            foundation_id=f.id, name=f"Test Animal {n}", species="gato", gender="hembra", size="pequeño",
            energy_level=2, location=WKTElement("POINT(-72.0685 -45.5712)", srid=4326),
        )
        for f, n in zip(foundations, ("A", "B"))
    ]
    db_session.add_all(animals)
    await db_session.commit()

    headers = {
        key: await login_headers(async_client, u.email, "user" if key == "adopter" else "foundation")
        for key, u in users.items()
    }
    yield {"foundations": foundations, "animals": animals, "headers": headers}

    await db_session.execute(delete(Animal).where(Animal.foundation_id.in_([f.id for f in foundations])))
    await db_session.execute(delete(User).where(User.id.in_([u.id for u in users.values()])))
    await db_session.execute(delete(Foundation).where(Foundation.id.in_([f.id for f in foundations])))
    await db_session.commit()


async def test_foundation_creates_animal_in_its_own_foundation(async_client, world):
    response = await async_client.post("/api/v1/animals", json=NEW_ANIMAL, headers=world["headers"]["a"])
    assert response.status_code == 201
    data = response.json()
    assert data["foundation_id"] == world["foundations"][0].id
    assert data["status"] == "available"
    assert data["latitude"] == pytest.approx(-45.5712)
    assert data["longitude"] == pytest.approx(-72.0685)
    assert "location" not in data


async def test_foundation_cannot_create_in_another_foundation(async_client, world):
    body = {**NEW_ANIMAL, "foundation_id": world["foundations"][1].id}
    response = await async_client.post("/api/v1/animals", json=body, headers=world["headers"]["a"])
    assert response.status_code == 403


async def test_create_requires_login(async_client, world):
    response = await async_client.post("/api/v1/animals", json=NEW_ANIMAL)
    assert response.status_code in (401, 403)  # HTTPBearer responde 403 o 401 según la versión de FastAPI


async def test_adopter_and_unlinked_foundation_cannot_create(async_client, world):
    for key in ("adopter", "sin_fundacion"):
        response = await async_client.post("/api/v1/animals", json=NEW_ANIMAL, headers=world["headers"][key])
        assert response.status_code == 403, key


async def test_create_validates_fields_in_spanish_friendly_shape(async_client, world):
    headers = world["headers"]["a"]
    for patch in (
        {"species": "dragón"},
        {"size": "gigante"},
        {"energy_level": 9},
        {"name": "   "},
        {"latitude": None},  # coordenadas incompletas
    ):
        response = await async_client.post("/api/v1/animals", json={**NEW_ANIMAL, **patch}, headers=headers)
        assert response.status_code == 422, patch


async def test_admin_must_choose_foundation_when_creating(async_client, world):
    headers = world["headers"]["admin"]
    assert (await async_client.post("/api/v1/animals", json=NEW_ANIMAL, headers=headers)).status_code == 422
    body = {**NEW_ANIMAL, "foundation_id": world["foundations"][1].id}
    response = await async_client.post("/api/v1/animals", json=body, headers=headers)
    assert response.status_code == 201
    assert response.json()["foundation_id"] == world["foundations"][1].id


async def test_foundation_updates_own_animal_and_changes_status(async_client, world):
    animal = world["animals"][0]
    response = await async_client.patch(
        f"/api/v1/animals/{animal.id}",
        json={"status": "in_process", "name": "Test Renombrado", "latitude": -45.6, "longitude": -72.1},
        headers=world["headers"]["a"],
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "in_process"
    assert data["name"] == "Test Renombrado"
    assert data["latitude"] == pytest.approx(-45.6)
    assert data["species"] == "gato"  # lo no enviado no cambia


async def test_update_rejects_null_required_fields_and_bad_status(async_client, world):
    url = f"/api/v1/animals/{world['animals'][0].id}"
    headers = world["headers"]["a"]
    assert (await async_client.patch(url, json={"name": None}, headers=headers)).status_code == 422
    assert (await async_client.patch(url, json={"status": "perdido"}, headers=headers)).status_code == 422
    assert (await async_client.patch(url, json={"latitude": -45.0}, headers=headers)).status_code == 422


async def test_foundation_cannot_edit_or_delete_another_foundations_animal(async_client, world):
    other = world["animals"][1]
    headers = world["headers"]["a"]
    patch = await async_client.patch(f"/api/v1/animals/{other.id}", json={"status": "adopted"}, headers=headers)
    delete_response = await async_client.delete(f"/api/v1/animals/{other.id}", headers=headers)
    assert patch.status_code == 403
    assert delete_response.status_code == 403


async def test_missing_animal_returns_404(async_client, world):
    response = await async_client.patch(
        "/api/v1/animals/999999999", json={"status": "adopted"}, headers=world["headers"]["a"]
    )
    assert response.status_code == 404


async def test_adopter_cannot_edit_or_delete(async_client, world):
    url = f"/api/v1/animals/{world['animals'][0].id}"
    headers = world["headers"]["adopter"]
    assert (await async_client.patch(url, json={"status": "adopted"}, headers=headers)).status_code == 403
    assert (await async_client.delete(url, headers=headers)).status_code == 403


async def test_foundation_deletes_own_animal(async_client, world):
    url = f"/api/v1/animals/{world['animals'][0].id}"
    assert (await async_client.delete(url, headers=world["headers"]["a"])).status_code == 204
    assert (await async_client.delete(url, headers=world["headers"]["a"])).status_code == 404


async def test_admin_edits_and_deletes_any_animal(async_client, world):
    headers = world["headers"]["admin"]
    url = f"/api/v1/animals/{world['animals'][1].id}"
    assert (await async_client.patch(url, json={"status": "adopted"}, headers=headers)).status_code == 200
    assert (await async_client.delete(url, headers=headers)).status_code == 204


async def test_list_is_filtered_for_foundations_but_not_for_others(async_client, world):
    own, other = world["animals"]

    def ids(response):
        return {a["id"] for a in response.json()}

    as_a = await async_client.get("/api/v1/animals", headers=world["headers"]["a"])
    assert own.id in ids(as_a) and other.id not in ids(as_a)
    assert {a["foundation_id"] for a in as_a.json()} == {world["foundations"][0].id}

    for headers in (None, world["headers"]["admin"], world["headers"]["adopter"]):
        response = await async_client.get("/api/v1/animals", headers=headers)
        assert {own.id, other.id} <= ids(response)

    unlinked = await async_client.get("/api/v1/animals", headers=world["headers"]["sin_fundacion"])
    assert unlinked.json() == []


async def test_invalid_token_is_treated_as_visitor_on_public_list(async_client, world):
    response = await async_client.get("/api/v1/animals", headers={"Authorization": "Bearer token-falso"})
    assert response.status_code == 200
