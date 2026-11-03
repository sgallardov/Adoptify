import random
import uuid

import pytest
from geoalchemy2.elements import WKTElement
from httpx import AsyncClient
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.report import AbandonedDogReport
from app.models.user import User


@pytest.fixture
async def make_user(async_client: AsyncClient, db_session: AsyncSession):
    """Crea usuarios con sesión iniciada y los elimina al terminar (sus "me enteré" se borran en cascada)."""
    emails = []

    async def create() -> dict:
        email = f"social_{uuid.uuid4().hex[:10]}@adoptify.cl"
        rut = f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}"
        await async_client.post(
            "/api/v1/auth/register",
            json={"email": email, "rut": rut, "password": "ClaveSegura123", "full_name": "Vecino Prueba"},
        )
        login = await async_client.post("/api/v1/auth/login", json={"email": email, "password": "ClaveSegura123"})
        emails.append(email)
        return {"Authorization": f"Bearer {login.json()['access_token']}"}

    yield create

    await db_session.execute(delete(User).where(User.email.in_(emails)))
    await db_session.commit()


@pytest.fixture
async def report(db_session: AsyncSession):
    """Un reporte de prueba; al borrarlo se borran en cascada sus comentarios y "me enteré"."""
    item = AbandonedDogReport(
        description="Test social", status="reported",
        location=WKTElement("POINT(-72.0685 -45.5712)", srid=4326),
    )
    db_session.add(item)
    await db_session.commit()
    yield item
    await db_session.execute(delete(AbandonedDogReport).where(AbandonedDogReport.id == item.id))
    await db_session.commit()


class TestComments:
    """Comentarios anónimos de un reporte (GET/POST /api/v1/reports/{id}/comments)."""

    async def test_comments_are_anonymous_and_in_order(self, async_client: AsyncClient, make_user, report):
        alice, bob = await make_user(), await make_user()
        url = f"/api/v1/reports/{report.id}/comments"

        first = await async_client.post(url, json={"body": "  Lo vi recién en la esquina  "}, headers=alice)
        assert first.status_code == 201
        assert first.json()["body"] == "Lo vi recién en la esquina"
        assert first.json()["is_mine"] is True
        await async_client.post(url, json={"body": "Voy en camino con una correa"}, headers=bob)

        data = (await async_client.get(url, headers=alice)).json()
        assert [c["body"] for c in data] == ["Lo vi recién en la esquina", "Voy en camino con una correa"]
        assert [c["is_mine"] for c in data] == [True, False]
        # Nunca se expone quién escribió
        assert set(data[0]) == {"id", "body", "created_at", "is_mine"}

    async def test_anyone_can_read_but_only_logged_in_can_write(self, async_client: AsyncClient, make_user, report):
        url = f"/api/v1/reports/{report.id}/comments"
        await async_client.post(url, json={"body": "Hola"}, headers=await make_user())

        public = await async_client.get(url)
        assert public.status_code == 200
        assert public.json()[0]["is_mine"] is False

        anonymous = await async_client.post(url, json={"body": "Sin cuenta"})
        assert anonymous.status_code in (401, 403)

    async def test_rejects_empty_or_long_comments(self, async_client: AsyncClient, make_user, report):
        headers = await make_user()
        url = f"/api/v1/reports/{report.id}/comments"
        assert (await async_client.post(url, json={"body": "   "}, headers=headers)).status_code == 422
        assert (await async_client.post(url, json={"body": "a" * 501}, headers=headers)).status_code == 422

    async def test_unknown_report_returns_404(self, async_client: AsyncClient, make_user):
        assert (await async_client.get("/api/v1/reports/999999999/comments")).status_code == 404
        response = await async_client.post(
            "/api/v1/reports/999999999/comments", json={"body": "Hola"}, headers=await make_user()
        )
        assert response.status_code == 404


class TestLikes:
    """"Me enteré" de un reporte (GET/PUT/DELETE /api/v1/reports/{id}/likes)."""

    async def test_like_counts_once_per_user_and_can_be_removed(self, async_client: AsyncClient, make_user, report):
        alice, bob = await make_user(), await make_user()
        url = f"/api/v1/reports/{report.id}/likes"

        assert (await async_client.get(url)).json() == {"count": 0, "liked": False}

        assert (await async_client.put(url, headers=alice)).json() == {"count": 1, "liked": True}
        # Marcarlo de nuevo no suma
        assert (await async_client.put(url, headers=alice)).json() == {"count": 1, "liked": True}
        assert (await async_client.put(url, headers=bob)).json() == {"count": 2, "liked": True}

        assert (await async_client.get(url)).json() == {"count": 2, "liked": False}
        assert (await async_client.delete(url, headers=alice)).json() == {"count": 1, "liked": False}
        assert (await async_client.get(url, headers=bob)).json() == {"count": 1, "liked": True}

    async def test_like_requires_login(self, async_client: AsyncClient, report):
        assert (await async_client.put(f"/api/v1/reports/{report.id}/likes")).status_code in (401, 403)

    async def test_unknown_report_returns_404(self, async_client: AsyncClient, make_user):
        response = await async_client.put("/api/v1/reports/999999999/likes", headers=await make_user())
        assert response.status_code == 404


async def test_deleting_report_deletes_its_comments(async_client: AsyncClient, db_session: AsyncSession, make_user):
    from app.models.report_social import ReportComment

    item = AbandonedDogReport(
        description="Test cascada", status="reported",
        location=WKTElement("POINT(-72.0685 -45.5712)", srid=4326),
    )
    db_session.add(item)
    await db_session.commit()
    await async_client.post(f"/api/v1/reports/{item.id}/comments", json={"body": "Hola"}, headers=await make_user())

    await db_session.execute(delete(AbandonedDogReport).where(AbandonedDogReport.id == item.id))
    await db_session.commit()
    remaining = (await db_session.execute(select(ReportComment).where(ReportComment.report_id == item.id))).all()
    assert remaining == []
