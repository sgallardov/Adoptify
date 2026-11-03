"""Fotos privadas en Supabase Storage: solo usuarios con sesión reciben enlaces para verlas."""
import random
import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.report import AbandonedDogReport
from app.models.user import User
from app.services import storage

PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64
BASE = "https://abc.supabase.co"
# Coyhaique: lejos del seed y de las demás pruebas
REPORT = {
    "latitude": -45.58, "longitude": -72.07, "species": "perro", "size": "mediano", "color": "Café",
    "conditions": ["herido"], "description": "Test foto privada cerca del paradero",
}
NEARBY = "/api/v1/reports/nearby?lat=-45.58&lng=-72.07&radius_km=1"


def signed(name: str) -> str:
    return f"{BASE}/storage/v1/object/sign/fotos/{name}?token=firmado"


@pytest.fixture
def bucket(monkeypatch):
    """Storage activado, con Supabase simulado: guarda lo que se sube y lo que se pide firmar."""
    state = {"uploaded": [], "sign_requests": [], "fail_signing": False}

    async def fake_upload(filename, content, extension):
        state["uploaded"].append(filename)
        return storage.reference(filename)

    async def fake_signed_urls(filenames):
        state["sign_requests"].append(set(filenames))
        if state["fail_signing"]:
            raise storage.StorageError("caído")
        return {name: signed(name) for name in filenames}

    monkeypatch.setattr(settings, "SUPABASE_URL", BASE)
    monkeypatch.setattr(settings, "SUPABASE_SERVICE_KEY", "sb_secret_prueba")
    monkeypatch.setattr(storage, "upload_photo", fake_upload)
    monkeypatch.setattr(storage, "signed_urls", fake_signed_urls)
    return state


@pytest.fixture
async def auth_headers(async_client: AsyncClient, db_session: AsyncSession):
    """Usuario con sesión; al terminar se borran sus reportes y su cuenta."""
    email = f"foto_{uuid.uuid4().hex[:10]}@adoptify.cl"
    rut = f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}"
    await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "rut": rut, "password": "ClaveSegura123", "full_name": "Usuario Foto"},
    )
    login = await async_client.post("/api/v1/auth/login", json={"email": email, "password": "ClaveSegura123"})
    yield {"Authorization": f"Bearer {login.json()['access_token']}"}
    user_id = (await db_session.execute(select(User.id).where(User.email == email))).scalar_one()
    await db_session.execute(delete(AbandonedDogReport).where(AbandonedDogReport.reporter_id == user_id))
    await db_session.execute(delete(User).where(User.id == user_id))
    await db_session.commit()


class TestReferences:
    """Qué se reconoce como foto del bucket y qué se guarda en la BD."""

    def test_recognizes_bucket_photos_in_every_form(self, monkeypatch):
        monkeypatch.setattr(settings, "SUPABASE_URL", BASE)
        assert storage.filename_of("storage:a1.jpg") == "a1.jpg"
        assert storage.filename_of(f"{BASE}/storage/v1/object/public/fotos/a1.jpg") == "a1.jpg"
        assert storage.filename_of(f"{BASE}/storage/v1/object/sign/fotos/a1.jpg?token=x") == "a1.jpg"

    def test_other_links_are_left_alone(self, monkeypatch):
        monkeypatch.setattr(settings, "SUPABASE_URL", BASE)
        assert storage.filename_of("https://images.unsplash.com/photo-1.jpg") is None
        assert storage.filename_of("http://10.0.2.2:8000/uploads/a1.jpg") is None
        assert storage.filename_of("https://otro.supabase.co/storage/v1/object/sign/fotos/a1.jpg") is None
        assert storage.to_reference("https://images.unsplash.com/photo-1.jpg") == "https://images.unsplash.com/photo-1.jpg"

    def test_signed_link_is_stored_as_reference(self, monkeypatch):
        monkeypatch.setattr(settings, "SUPABASE_URL", BASE)
        assert storage.to_reference(signed("a1.jpg")) == "storage:a1.jpg"


class TestPrivatePhotos:
    """Solo quien tiene sesión ve las fotos del bucket privado."""

    async def test_upload_returns_a_signed_link(self, async_client, auth_headers, bucket):
        response = await async_client.post(
            "/api/v1/uploads", files={"file": ("foto.png", PNG, "image/png")}, headers=auth_headers
        )
        assert response.status_code == 201
        name = bucket["uploaded"][0]
        assert response.json()["url"] == signed(name)

    async def test_report_photo_only_for_logged_in_users(
        self, async_client, auth_headers, bucket, db_session: AsyncSession
    ):
        # La app crea el reporte con el enlace firmado que recibió al subir la foto
        created = await async_client.post(
            "/api/v1/reports", json={**REPORT, "photo_url": signed("perro.jpg")}, headers=auth_headers
        )
        assert created.status_code == 201
        assert created.json()["photo_url"] == signed("perro.jpg")
        stored = (await db_session.execute(
            select(AbandonedDogReport.photo_url).where(AbandonedDogReport.id == created.json()["id"])
        )).scalar_one()
        assert stored == "storage:perro.jpg"

        with_session = (await async_client.get(NEARBY, headers=auth_headers)).json()
        mine = next(r for r in with_session if r["id"] == created.json()["id"])
        assert mine["photo_url"] == signed("perro.jpg")

        visitor = (await async_client.get(NEARBY)).json()
        assert next(r for r in visitor if r["id"] == created.json()["id"])["photo_url"] is None

        expired = (await async_client.get(NEARBY, headers={"Authorization": "Bearer token-falso"})).json()
        assert next(r for r in expired if r["id"] == created.json()["id"])["photo_url"] is None

    async def test_external_photos_are_not_touched(self, async_client, auth_headers, bucket):
        unsplash = "https://images.unsplash.com/photo-1.jpg"
        created = await async_client.post("/api/v1/reports", json={**REPORT, "photo_url": unsplash}, headers=auth_headers)
        assert created.json()["photo_url"] == unsplash
        visitor = (await async_client.get(NEARBY)).json()
        assert next(r for r in visitor if r["id"] == created.json()["id"])["photo_url"] == unsplash

    async def test_one_signing_call_per_response(self, async_client, auth_headers, bucket):
        for name in ("a.jpg", "b.jpg"):
            await async_client.post("/api/v1/reports", json={**REPORT, "photo_url": f"storage:{name}"}, headers=auth_headers)
        bucket["sign_requests"].clear()
        await async_client.get(NEARBY, headers=auth_headers)
        assert len(bucket["sign_requests"]) == 1
        assert {"a.jpg", "b.jpg"} <= bucket["sign_requests"][0]

    async def test_storage_down_keeps_the_app_working(self, async_client, auth_headers, bucket):
        created = await async_client.post(
            "/api/v1/reports", json={**REPORT, "photo_url": "storage:c.jpg"}, headers=auth_headers
        )
        bucket["fail_signing"] = True
        response = await async_client.get(NEARBY, headers=auth_headers)
        assert response.status_code == 200
        assert next(r for r in response.json() if r["id"] == created.json()["id"])["photo_url"] is None
