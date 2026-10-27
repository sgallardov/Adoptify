import random
import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import delete, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


def unique_email() -> str:
    """Genera un correo único para que las pruebas no choquen entre sí."""
    return f"login_{uuid.uuid4().hex[:10]}@adoptify.cl"


def unique_rut() -> str:
    """Genera un RUT con formato válido y muy probablemente único (los usuarios no pueden repetir RUT)."""
    return f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}"


@pytest.fixture
async def registered_email(db_session: AsyncSession):
    """Registra un usuario de prueba y lo elimina al terminar la prueba."""
    email = unique_email()
    yield email
    await db_session.execute(delete(User).where(User.email == email))
    await db_session.commit()


class TestLoginEmailPassword:
    """
    Pruebas del registro, inicio de sesión y sesión (correo y contraseña).
    """

    async def test_register_creates_user_without_exposing_password(self, async_client: AsyncClient, registered_email: str):
        response = await async_client.post(
            "/api/v1/auth/register",
            json={"email": registered_email, "rut": unique_rut(), "password": "ClaveSegura123", "full_name": "Usuaria Prueba"},
        )

        assert response.status_code == 201
        data = response.json()
        assert data["email"] == registered_email
        assert data["role"] == "adopter"
        assert "password" not in data
        assert "hashed_password" not in data

    async def test_register_duplicate_email_returns_409(self, async_client: AsyncClient, registered_email: str):
        payload = {"email": registered_email, "rut": unique_rut(), "password": "ClaveSegura123", "full_name": "Usuario Prueba"}
        await async_client.post("/api/v1/auth/register", json=payload)

        response = await async_client.post("/api/v1/auth/register", json=payload)

        assert response.status_code == 409

    async def test_login_with_correct_password_returns_token(self, async_client: AsyncClient, registered_email: str):
        await async_client.post(
            "/api/v1/auth/register",
            json={"email": registered_email, "rut": unique_rut(), "password": "ClaveSegura123", "full_name": "Usuario Prueba"},
        )

        response = await async_client.post(
            "/api/v1/auth/login",
            json={"email": registered_email, "password": "ClaveSegura123"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["token_type"] == "bearer"
        assert data["access_token"]

    async def test_login_with_wrong_password_returns_401(self, async_client: AsyncClient, registered_email: str):
        await async_client.post(
            "/api/v1/auth/register",
            json={"email": registered_email, "rut": unique_rut(), "password": "ClaveSegura123", "full_name": "Usuario Prueba"},
        )

        response = await async_client.post(
            "/api/v1/auth/login",
            json={"email": registered_email, "password": "ClaveIncorrecta"},
        )

        assert response.status_code == 401

    async def test_login_with_unknown_email_returns_401(self, async_client: AsyncClient):
        response = await async_client.post(
            "/api/v1/auth/login",
            json={"email": unique_email(), "password": "ClaveSegura123"},
        )

        assert response.status_code == 401

    async def test_me_without_token_returns_401(self, async_client: AsyncClient):
        response = await async_client.get("/api/v1/auth/me")

        assert response.status_code in (401, 403)

    async def test_me_with_valid_token_returns_current_user(self, async_client: AsyncClient, registered_email: str):
        await async_client.post(
            "/api/v1/auth/register",
            json={"email": registered_email, "rut": unique_rut(), "password": "ClaveSegura123", "full_name": "Usuario Prueba"},
        )
        login = await async_client.post(
            "/api/v1/auth/login",
            json={"email": registered_email, "password": "ClaveSegura123"},
        )
        token = login.json()["access_token"]

        response = await async_client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )

        assert response.status_code == 200
        assert response.json()["email"] == registered_email


class TestLoginAccountTabs:
    """
    Pruebas del login con pestañas: 'user' (adoptantes) y 'foundation' (fundaciones).
    """

    async def test_adopter_logs_in_through_user_tab(self, async_client: AsyncClient, registered_email: str):
        await async_client.post(
            "/api/v1/auth/register",
            json={"email": registered_email, "rut": unique_rut(), "password": "ClaveSegura123", "full_name": "Usuario Prueba"},
        )

        response = await async_client.post(
            "/api/v1/auth/login",
            json={"email": registered_email, "password": "ClaveSegura123", "account_type": "user"},
        )

        assert response.status_code == 200
        assert response.json()["role"] == "adopter"

    async def test_adopter_cannot_log_in_through_foundation_tab(self, async_client: AsyncClient, registered_email: str):
        await async_client.post(
            "/api/v1/auth/register",
            json={"email": registered_email, "rut": unique_rut(), "password": "ClaveSegura123", "full_name": "Usuario Prueba"},
        )

        response = await async_client.post(
            "/api/v1/auth/login",
            json={"email": registered_email, "password": "ClaveSegura123", "account_type": "foundation"},
        )

        assert response.status_code == 403
        assert "Usuario" in response.json()["detail"]

    async def test_foundation_logs_in_only_through_foundation_tab(
        self, async_client: AsyncClient, db_session: AsyncSession, registered_email: str
    ):
        await async_client.post(
            "/api/v1/auth/register",
            json={"email": registered_email, "rut": unique_rut(), "password": "ClaveSegura123", "full_name": "Fundación Prueba"},
        )
        await db_session.execute(update(User).where(User.email == registered_email).values(role="foundation"))
        await db_session.commit()

        foundation_tab = await async_client.post(
            "/api/v1/auth/login",
            json={"email": registered_email, "password": "ClaveSegura123", "account_type": "foundation"},
        )
        user_tab = await async_client.post(
            "/api/v1/auth/login",
            json={"email": registered_email, "password": "ClaveSegura123", "account_type": "user"},
        )

        assert foundation_tab.status_code == 200
        assert foundation_tab.json()["role"] == "foundation"
        assert user_tab.status_code == 403


class TestLoginInputNormalization:
    """
    Casos borde del registro y login: mayúsculas en el correo y el límite de 72 bytes de bcrypt.
    """

    async def test_email_is_case_insensitive(self, async_client: AsyncClient, registered_email: str):
        await async_client.post(
            "/api/v1/auth/register",
            json={"email": registered_email.upper(), "rut": unique_rut(), "password": "ClaveSegura123", "full_name": "Usuario Prueba"},
        )

        login = await async_client.post(
            "/api/v1/auth/login",
            json={"email": registered_email, "password": "ClaveSegura123"},
        )
        duplicate = await async_client.post(
            "/api/v1/auth/register",
            json={"email": registered_email, "rut": unique_rut(), "password": "ClaveSegura123", "full_name": "Otro Usuario"},
        )

        assert login.status_code == 200
        assert duplicate.status_code == 409

    async def test_password_over_72_bytes_returns_422(self, async_client: AsyncClient):
        response = await async_client.post(
            "/api/v1/auth/register",
            json={"email": unique_email(), "rut": unique_rut(), "password": "ñ" * 40, "full_name": "Usuario Prueba"},
        )

        assert response.status_code == 422


class TestUserRut:
    """
    El RUT es un atributo obligatorio y único de cada usuario. Solo se revisa su formato.
    """

    async def test_register_stores_rut_without_dots(self, async_client: AsyncClient, registered_email: str):
        rut = unique_rut()
        body, verifier = rut.split("-")
        with_dots = f"{body[:2]}.{body[2:5]}.{body[5:]}-{verifier.lower()}"

        response = await async_client.post(
            "/api/v1/auth/register",
            json={"email": registered_email, "rut": with_dots, "password": "ClaveSegura123", "full_name": "Usuario Prueba"},
        )

        assert response.status_code == 201
        assert response.json()["rut"] == rut

    async def test_register_without_rut_returns_422(self, async_client: AsyncClient):
        response = await async_client.post(
            "/api/v1/auth/register",
            json={"email": unique_email(), "password": "ClaveSegura123", "full_name": "Usuario Prueba"},
        )

        assert response.status_code == 422

    @pytest.mark.parametrize("bad_rut", ["12345678", "12.345678-5", "1234-5", "12345678-X", "abc"])
    async def test_register_with_invalid_rut_format_returns_422(self, async_client: AsyncClient, bad_rut: str):
        response = await async_client.post(
            "/api/v1/auth/register",
            json={"email": unique_email(), "rut": bad_rut, "password": "ClaveSegura123", "full_name": "Usuario Prueba"},
        )

        assert response.status_code == 422

    async def test_register_duplicate_rut_returns_409(
        self, async_client: AsyncClient, db_session: AsyncSession, registered_email: str
    ):
        rut = unique_rut()
        await async_client.post(
            "/api/v1/auth/register",
            json={"email": registered_email, "rut": rut, "password": "ClaveSegura123", "full_name": "Usuario Prueba"},
        )
        other_email = unique_email()

        response = await async_client.post(
            "/api/v1/auth/register",
            json={"email": other_email, "rut": rut, "password": "ClaveSegura123", "full_name": "Otro Usuario"},
        )

        assert response.status_code == 409
        assert "RUT" in response.json()["detail"]
        await db_session.execute(delete(User).where(User.email == other_email))
        await db_session.commit()

    async def test_me_includes_rut(self, async_client: AsyncClient, registered_email: str):
        rut = unique_rut()
        await async_client.post(
            "/api/v1/auth/register",
            json={"email": registered_email, "rut": rut, "password": "ClaveSegura123", "full_name": "Usuario Prueba"},
        )
        login = await async_client.post(
            "/api/v1/auth/login",
            json={"email": registered_email, "password": "ClaveSegura123"},
        )

        response = await async_client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {login.json()['access_token']}"},
        )

        assert response.json()["rut"] == rut
