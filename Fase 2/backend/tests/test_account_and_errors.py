"""Editar el nombre y la contraseña, errores en español y permisos de veterinarias antes que la validación."""
import random
import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.foundation import Foundation
from app.models.user import User

PASSWORD = "ClaveSegura123"
NEW_PASSWORD = "OtraClaveSegura456"


def unique_rut() -> str:
    return f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}"


@pytest.fixture
async def accounts(async_client: AsyncClient, db_session: AsyncSession):
    tag = uuid.uuid4().hex[:8]
    foundation = Foundation(name=f"Test Cuenta {tag}", rut=unique_rut(), email=f"test_cuenta_f_{tag}@adoptify.cl")
    db_session.add(foundation)
    await db_session.flush()

    def user(label: str, role: str, foundation_id: int | None = None) -> User:
        return User(
            email=f"test_cuenta_{label}_{tag}@adoptify.cl", rut=unique_rut(), hashed_password=hash_password(PASSWORD),
            full_name=f"Test {label}", role=role, foundation_id=foundation_id, preferences={},
        )

    users = {
        "adopter": user("adopter", "adopter"),
        "foundation": user("foundation", "foundation", foundation.id),
        "admin": user("admin", "admin"),
    }
    db_session.add_all(users.values())
    await db_session.commit()

    headers = {}
    for key, u in users.items():
        response = await async_client.post("/api/v1/auth/login", json={"email": u.email, "password": PASSWORD})
        headers[key] = {"Authorization": f"Bearer {response.json()['access_token']}"}
    yield {"users": users, "headers": headers}

    await db_session.execute(delete(User).where(User.id.in_([u.id for u in users.values()])))
    await db_session.execute(delete(Foundation).where(Foundation.id == foundation.id))
    await db_session.commit()


# ---------- Editar nombre ----------

async def test_edit_full_name_trims_and_saves(async_client, accounts):
    headers = accounts["headers"]["adopter"]
    response = await async_client.patch("/api/v1/auth/me", json={"full_name": "  Matías Morales  "}, headers=headers)
    assert response.status_code == 200
    assert response.json()["full_name"] == "Matías Morales"
    assert (await async_client.get("/api/v1/auth/me", headers=headers)).json()["full_name"] == "Matías Morales"


async def test_edit_full_name_uses_registration_rules_in_spanish(async_client, accounts):
    headers = accounts["headers"]["adopter"]
    too_short = await async_client.patch("/api/v1/auth/me", json={"full_name": "M"}, headers=headers)
    assert too_short.status_code == 422
    assert too_short.json()["detail"][0]["msg"] == "Nombre: debe tener al menos 2 caracteres."
    # Solo espacios: lo rechaza el mismo validador del registro
    blank = await async_client.patch("/api/v1/auth/me", json={"full_name": "     "}, headers=headers)
    assert blank.status_code == 422
    assert blank.json()["detail"][0]["msg"] == "El nombre debe tener al menos 2 caracteres"


async def test_edit_requires_login(async_client):
    response = await async_client.patch("/api/v1/auth/me", json={"full_name": "Alguien"})
    assert response.status_code == 401
    assert response.json()["detail"] == "Inicia sesión para continuar."


# ---------- Cambiar contraseña ----------

async def test_change_password_and_login_with_the_new_one(async_client, accounts):
    user = accounts["users"]["adopter"]
    headers = accounts["headers"]["adopter"]
    response = await async_client.post(
        "/api/v1/auth/change-password",
        json={"current_password": PASSWORD, "new_password": NEW_PASSWORD},
        headers=headers,
    )
    assert response.status_code == 204
    # La sesión actual sigue abierta
    assert (await async_client.get("/api/v1/auth/me", headers=headers)).status_code == 200
    old = await async_client.post("/api/v1/auth/login", json={"email": user.email, "password": PASSWORD})
    new = await async_client.post("/api/v1/auth/login", json={"email": user.email, "password": NEW_PASSWORD})
    assert old.status_code == 401
    assert new.status_code == 200


async def test_wrong_current_password_is_400_not_401(async_client, accounts):
    response = await async_client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "NoEsLaClave1", "new_password": NEW_PASSWORD},
        headers=accounts["headers"]["adopter"],
    )
    # 400: la app y el portal cierran sesión ante cualquier 401
    assert response.status_code == 400
    assert response.json()["detail"] == "La contraseña actual no es correcta."


async def test_new_password_must_be_different_and_long_enough(async_client, accounts):
    headers = accounts["headers"]["foundation"]
    same = await async_client.post(
        "/api/v1/auth/change-password", json={"current_password": PASSWORD, "new_password": PASSWORD}, headers=headers,
    )
    assert same.status_code == 400
    assert same.json()["detail"] == "La nueva contraseña debe ser distinta de la actual."

    short = await async_client.post(
        "/api/v1/auth/change-password", json={"current_password": PASSWORD, "new_password": "corta"}, headers=headers,
    )
    assert short.status_code == 422
    assert short.json()["detail"][0]["msg"] == "Nueva contraseña: debe tener al menos 8 caracteres."
    # El 422 no repite lo que se envió (podría ser una contraseña)
    assert "input" not in short.json()["detail"][0]
    assert "corta" not in short.text


# ---------- Errores en español ----------

async def test_missing_token_is_401_in_spanish(async_client):
    response = await async_client.get("/api/v1/auth/me")
    assert response.status_code == 401
    assert response.json()["detail"] == "Inicia sesión para continuar."


async def test_validation_errors_are_in_spanish_and_keep_their_shape(async_client):
    response = await async_client.post("/api/v1/auth/register", json={"email": "no-es-correo", "rut": "1-9"})
    assert response.status_code == 422
    detail = response.json()["detail"]
    assert all({"loc", "msg", "type"} <= set(item) for item in detail)
    messages = {item["loc"][-1]: item["msg"] for item in detail}
    assert messages["password"] == "Contraseña: es obligatorio."
    assert messages["full_name"] == "Nombre: es obligatorio."
    assert messages["email"] == "Correo: no es un correo válido."
    assert not any("should" in item["msg"] or "required" in item["msg"] for item in detail)


async def test_query_validation_in_spanish(async_client):
    response = await async_client.get("/api/v1/animals/nearby", params={"lat": -33.4, "lng": -70.6, "radius_km": 500})
    assert response.status_code == 422
    assert response.json()["detail"][0]["msg"] == "Radio: debe ser menor o igual a 100."


async def test_unknown_route_is_404_in_spanish(async_client):
    response = await async_client.get("/api/v1/no-existe")
    assert response.status_code == 404
    assert response.json()["detail"] == "No encontrado."


async def test_login_message_does_not_mention_tabs(async_client, accounts):
    adopter = accounts["users"]["adopter"]
    response = await async_client.post(
        "/api/v1/auth/login", json={"email": adopter.email, "password": PASSWORD, "account_type": "foundation"},
    )
    assert response.status_code == 403
    assert "pestaña" not in response.json()["detail"]
    assert response.json()["detail"] == "Esta cuenta es de adoptante. Inicia sesión desde la app de Adoptify."


# ---------- Veterinarias: permiso antes que validación ----------

@pytest.mark.parametrize("role", ["adopter", "foundation"])
async def test_vets_check_permission_before_body(async_client, accounts, role):
    headers = accounts["headers"][role]
    for path in ("/api/v1/veterinaries", "/api/v1/veterinary-clinics"):
        created = await async_client.post(path, json={"name": ""}, headers=headers)
        assert created.status_code == 403, path
        updated = await async_client.patch(f"{path}/1", json={"latitude": "no es número"}, headers=headers)
        assert updated.status_code == 403, path


async def test_admin_still_gets_validation_errors_for_vets(async_client, accounts):
    response = await async_client.post("/api/v1/veterinaries", json={"name": ""}, headers=accounts["headers"]["admin"])
    assert response.status_code == 422
