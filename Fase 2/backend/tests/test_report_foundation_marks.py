import random
import uuid

import pytest
from geoalchemy2.elements import WKTElement
from httpx import AsyncClient
from sqlalchemy import delete, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.foundation import Foundation
from app.models.report import AbandonedDogReport
from app.models.user import User


@pytest.fixture
async def report_world(async_client: AsyncClient, db_session: AsyncSession):
    tag = uuid.uuid4().hex[:8]
    password = "ClaveSegura123"
    foundations = [
        Foundation(name=f"Rescate {name}", rut=f"{random.randint(30_000_000, 99_999_999)}-{index}", email=f"{name}_{tag}@test.cl")
        for index, name in enumerate(("A", "B"), start=1)
    ]
    db_session.add_all(foundations)
    await db_session.flush()
    users = {
        "a": User(email=f"fundacion_a_{tag}@test.cl", rut=f"{random.randint(30_000_000, 99_999_999)}-3", hashed_password=hash_password(password), full_name="Fundación A", role="foundation", foundation_id=foundations[0].id),
        "b": User(email=f"fundacion_b_{tag}@test.cl", rut=f"{random.randint(30_000_000, 99_999_999)}-4", hashed_password=hash_password(password), full_name="Fundación B", role="foundation", foundation_id=foundations[1].id),
        "adopter": User(email=f"adopter_{tag}@test.cl", rut=f"{random.randint(30_000_000, 99_999_999)}-5", hashed_password=hash_password(password), full_name="Adoptante", role="adopter"),
    }
    report = AbandonedDogReport(description="Reporte para gestión de fundaciones", status="reported", location=WKTElement("POINT(-72.07 -45.58)", srid=4326))
    db_session.add_all([*users.values(), report])
    await db_session.commit()
    headers = {}
    for key, user in users.items():
        login = await async_client.post("/api/v1/auth/login", json={"email": user.email, "password": password})
        headers[key] = {"Authorization": f"Bearer {login.json()['access_token']}"}
    yield {"report": report, "foundations": foundations, "headers": headers}
    await db_session.execute(delete(AbandonedDogReport).where(AbandonedDogReport.id == report.id))
    await db_session.execute(delete(User).where(User.id.in_([user.id for user in users.values()])))
    await db_session.execute(delete(Foundation).where(Foundation.id.in_([foundation.id for foundation in foundations])))
    await db_session.commit()


async def test_foundation_can_see_take_and_undo_a_report(async_client, report_world):
    report_id = report_world["report"].id
    headers = report_world["headers"]
    seen = await async_client.post(f"/api/v1/reports/{report_id}/seen", headers=headers["a"])
    assert seen.status_code == 200
    assert seen.json()["status"] == "reported"
    assert seen.json()["seen_at"] is not None
    taken = await async_client.put(f"/api/v1/reports/{report_id}/taken", headers=headers["a"])
    assert taken.status_code == 200
    assert taken.json()["status"] == "in_rescue"
    assert taken.json()["foundation_name"] == report_world["foundations"][0].name
    assert taken.json()["taken_by_foundation_id"] == report_world["foundations"][0].id
    assert "reporter_id" not in taken.json()
    public = await async_client.get(f"/api/v1/reports/{report_id}")
    assert public.status_code == 200
    assert public.json()["foundation_name"] == report_world["foundations"][0].name
    assert "reporter_id" not in public.json()
    assert (await async_client.put(f"/api/v1/reports/{report_id}/taken", headers=headers["b"])).status_code == 409
    undone = await async_client.delete(f"/api/v1/reports/{report_id}/taken", headers=headers["a"])
    assert undone.status_code == 200
    assert undone.json()["status"] == "reported"
    assert undone.json()["foundation_name"] is None
    assert undone.json()["taken_by_foundation_id"] is None


async def test_taking_a_report_also_marks_it_as_seen(async_client, report_world):
    report_id = report_world["report"].id
    taken = await async_client.put(f"/api/v1/reports/{report_id}/taken", headers=report_world["headers"]["a"])
    assert taken.status_code == 200
    assert taken.json()["seen_at"] is not None
    # Deshacer la toma no borra que una fundación ya lo vio
    undone = await async_client.delete(f"/api/v1/reports/{report_id}/taken", headers=report_world["headers"]["a"])
    assert undone.json()["seen_at"] is not None


async def test_permissions_and_resolved_conflict(async_client, report_world, db_session: AsyncSession):
    report = report_world["report"]
    assert (await async_client.post(f"/api/v1/reports/{report.id}/seen", headers=report_world["headers"]["adopter"])).status_code == 403
    report.status = "resolved"
    await db_session.commit()
    assert (await async_client.post(f"/api/v1/reports/{report.id}/seen", headers=report_world["headers"]["a"])).status_code == 409
    assert (await async_client.put(f"/api/v1/reports/{report.id}/taken", headers=report_world["headers"]["a"])).status_code == 409


async def test_only_the_foundation_that_took_it_can_resolve(async_client, report_world):
    report_id = report_world["report"].id
    headers = report_world["headers"]
    url = f"/api/v1/reports/{report_id}/status"
    body = {"status": "resolved"}
    # Sin tomar el caso no se puede resolver
    assert (await async_client.patch(url, json=body, headers=headers["a"])).status_code == 409
    await async_client.put(f"/api/v1/reports/{report_id}/taken", headers=headers["a"])
    assert (await async_client.patch(url, json=body, headers=headers["b"])).status_code == 403
    assert (await async_client.patch(url, json=body, headers=headers["adopter"])).status_code == 403
    assert (await async_client.patch(url, json={"status": "reported"}, headers=headers["a"])).status_code == 422
    resolved = await async_client.patch(url, json=body, headers=headers["a"])
    assert resolved.status_code == 200
    assert resolved.json()["status"] == "resolved"
    # Ya resuelto: no se repite ni se puede deshacer la toma
    assert (await async_client.patch(url, json=body, headers=headers["a"])).status_code == 409
    assert (await async_client.delete(f"/api/v1/reports/{report_id}/taken", headers=headers["a"])).status_code == 409


async def test_resolved_and_expired_reports_leave_the_map(async_client, db_session, report_world):
    report = report_world["report"]
    headers = report_world["headers"]
    params = {"lat": -45.58, "lng": -72.07, "radius_km": 5}

    async def ids():
        return [item["id"] for item in (await async_client.get("/api/v1/reports/nearby", params=params)).json()]

    assert report.id in await ids()
    await async_client.put(f"/api/v1/reports/{report.id}/taken", headers=headers["a"])
    await async_client.patch(f"/api/v1/reports/{report.id}/status", json={"status": "resolved"}, headers=headers["a"])
    assert report.id not in await ids()
    # Vencido: más viejo que REPORT_TTL_DAYS
    await db_session.execute(text(
        "update abandoned_dog_reports set status='reported', created_at = now() - interval '31 days' where id = :id"
    ), {"id": report.id})
    await db_session.commit()
    assert report.id not in await ids()
