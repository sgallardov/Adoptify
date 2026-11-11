"""HU-E: el RUT de los usuarios se guarda cifrado y se busca por su hash."""
import random
import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import delete, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import rut_crypto
from app.core.config import settings
from app.models.user import User


def unique_email() -> str:
    return f"rut_{uuid.uuid4().hex[:10]}@adoptify.cl"


def unique_rut() -> str:
    return f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}"


def with_dots(rut: str) -> str:
    body, verifier = rut.split("-")
    return f"{body[:2]}.{body[2:5]}.{body[5:]}-{verifier.lower()}"


@pytest.fixture
async def emails(db_session: AsyncSession):
    """Correos de los usuarios que crea cada prueba; se borran al terminar."""
    created: list[str] = []
    yield created
    if created:
        await db_session.execute(delete(User).where(User.email.in_(created)))
        await db_session.commit()


async def register(client: AsyncClient, emails: list[str], rut: str):
    email = unique_email()
    emails.append(email)
    response = await client.post(
        "/api/v1/auth/register",
        json={"email": email, "rut": rut, "password": "ClaveSegura123", "full_name": "Usuario Rut"},
    )
    return email, response


async def test_rut_is_not_stored_in_plain_text(async_client: AsyncClient, db_session: AsyncSession, emails):
    rut = unique_rut()
    email, response = await register(async_client, emails, with_dots(rut))
    assert response.status_code == 201

    columns = (await db_session.execute(
        text("SELECT column_name FROM information_schema.columns WHERE table_name = 'users'")
    )).scalars().all()
    assert "rut" not in columns

    row = (await db_session.execute(text("SELECT * FROM users WHERE email = :email"), {"email": email})).mappings().one()
    body = rut.split("-")[0]
    for value in row.values():
        assert body not in str(value)


async def test_lookup_by_normalized_rut_uses_the_hash(async_client: AsyncClient, db_session: AsyncSession, emails):
    rut = unique_rut()
    email, _ = await register(async_client, emails, rut)

    found = (await db_session.execute(select(User).where(User.rut_hash == rut_crypto.hash_rut(with_dots(rut))))).scalar_one()

    assert found.email == email
    assert found.rut == rut


async def test_duplicate_rut_written_differently_returns_409(async_client: AsyncClient, emails):
    rut = unique_rut()
    _, first = await register(async_client, emails, rut)
    _, second = await register(async_client, emails, with_dots(rut))

    assert first.status_code == 201
    assert second.status_code == 409
    assert "RUT" in second.json()["detail"]


async def test_me_returns_the_decrypted_rut_to_its_owner(async_client: AsyncClient, emails):
    rut = unique_rut()
    email, _ = await register(async_client, emails, rut)
    login = await async_client.post("/api/v1/auth/login", json={"email": email, "password": "ClaveSegura123"})

    me = await async_client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {login.json()['access_token']}"})

    assert me.status_code == 200
    assert me.json()["rut"] == rut


def test_encryption_is_not_deterministic_but_the_hash_is():
    rut = "12345678-5"
    assert rut_crypto.encrypt_rut(rut) != rut_crypto.encrypt_rut(rut)
    assert rut_crypto.hash_rut(rut) == rut_crypto.hash_rut("12.345.678-5")
    assert rut_crypto.decrypt_rut(rut_crypto.encrypt_rut("12.345.678-k")) == "12345678-K"


def test_shared_database_refuses_the_development_keys(monkeypatch):
    monkeypatch.setattr(settings, "DATABASE_URL", "postgresql+asyncpg://u:p@compartida/db")

    with pytest.raises(RuntimeError, match="RUT_ENCRYPTION_KEY"):
        rut_crypto.hash_rut("12345678-5")


def test_shared_database_works_with_its_own_keys(monkeypatch):
    from cryptography.fernet import Fernet

    monkeypatch.setattr(settings, "DATABASE_URL", "postgresql+asyncpg://u:p@compartida/db")
    monkeypatch.setattr(settings, "RUT_ENCRYPTION_KEY", Fernet.generate_key().decode())
    monkeypatch.setattr(settings, "RUT_HASH_KEY", "otra-clave-de-hash-larga")

    assert rut_crypto.decrypt_rut(rut_crypto.encrypt_rut("12345678-5")) == "12345678-5"


def test_a_different_key_cannot_decrypt(monkeypatch):
    from cryptography.fernet import Fernet

    token = rut_crypto.encrypt_rut("12345678-5")
    monkeypatch.setattr(settings, "RUT_ENCRYPTION_KEY", Fernet.generate_key().decode())

    with pytest.raises(RuntimeError, match="no coincide"):
        rut_crypto.decrypt_rut(token)
