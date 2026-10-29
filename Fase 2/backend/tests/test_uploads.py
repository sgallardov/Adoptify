import random
import uuid
from pathlib import Path

import pytest
from httpx import AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.user import User

JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 64
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


@pytest.fixture
async def auth_headers(async_client: AsyncClient, db_session: AsyncSession):
    """Registra un usuario, inicia sesión y lo elimina al terminar."""
    email = f"upload_{uuid.uuid4().hex[:10]}@adoptify.cl"
    rut = f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}"
    await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "rut": rut, "password": "ClaveSegura123", "full_name": "Usuario Subida"},
    )
    login = await async_client.post("/api/v1/auth/login", json={"email": email, "password": "ClaveSegura123"})
    yield {"Authorization": f"Bearer {login.json()['access_token']}"}
    await db_session.execute(delete(User).where(User.email == email))
    await db_session.commit()


@pytest.fixture
def uploaded_files():
    """Borra del disco las imágenes que crea cada prueba."""
    created: list[str] = []
    yield created
    for name in created:
        (Path(settings.UPLOAD_DIR) / name).unlink(missing_ok=True)


def upload(client: AsyncClient, content: bytes, name: str = "foto.jpg", headers: dict | None = None):
    return client.post("/api/v1/uploads", files={"file": (name, content, "application/octet-stream")}, headers=headers)


@pytest.mark.parametrize("content,extension", [(JPEG, "jpg"), (PNG, "png")])
async def test_valid_image_is_stored_and_served(async_client, auth_headers, uploaded_files, content, extension):
    response = await upload(async_client, content, "mi foto.bin", auth_headers)
    assert response.status_code == 201
    url = response.json()["url"]
    filename = url.rsplit("/", 1)[1]
    uploaded_files.append(filename)
    assert url.endswith(f".{extension}")
    assert "/uploads/" in url
    served = await async_client.get(f"/uploads/{filename}")
    assert served.status_code == 200
    assert served.content == content


async def test_original_filename_is_never_used(async_client, auth_headers, uploaded_files):
    response = await upload(async_client, JPEG, "../../etc/passwd.jpg", auth_headers)
    filename = response.json()["url"].rsplit("/", 1)[1]
    uploaded_files.append(filename)
    assert "passwd" not in filename and ".." not in filename


async def test_renamed_file_is_rejected_by_content(async_client, auth_headers):
    response = await upload(async_client, b"MZ\x90\x00 programa", "virus.jpg", auth_headers)
    assert response.status_code == 415
    assert "JPG o PNG" in response.json()["detail"]


async def test_empty_and_text_files_are_rejected(async_client, auth_headers):
    assert (await upload(async_client, b"", "vacio.png", auth_headers)).status_code == 415
    assert (await upload(async_client, b"hola", "nota.png", auth_headers)).status_code == 415


async def test_oversized_image_is_rejected(async_client, auth_headers, monkeypatch):
    monkeypatch.setattr(settings, "MAX_UPLOAD_MB", 1)
    response = await upload(async_client, JPEG + b"\x00" * (1024 * 1024), "grande.jpg", auth_headers)
    assert response.status_code == 413
    assert "muy pesada" in response.json()["detail"]


async def test_upload_requires_login(async_client):
    response = await upload(async_client, JPEG)
    assert response.status_code in (401, 403)


async def test_missing_file_returns_422(async_client, auth_headers):
    response = await async_client.post("/api/v1/uploads", headers=auth_headers)
    assert response.status_code == 422


async def test_public_base_url_is_used_when_configured(async_client, auth_headers, uploaded_files, monkeypatch):
    monkeypatch.setattr(settings, "PUBLIC_BASE_URL", "https://api.adoptify.cl/")
    response = await upload(async_client, PNG, "a.png", auth_headers)
    url = response.json()["url"]
    uploaded_files.append(url.rsplit("/", 1)[1])
    assert url.startswith("https://api.adoptify.cl/uploads/")
