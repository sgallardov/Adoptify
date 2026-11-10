import random
import uuid

import pytest
from geoalchemy2.elements import WKTElement
from httpx import AsyncClient
from sqlalchemy import delete
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


async def test_permissions_and_resolved_conflict(async_client, report_world, db_session: AsyncSession):
    report = report_world["report"]
    assert (await async_client.post(f"/api/v1/reports/{report.id}/seen", headers=report_world["headers"]["adopter"])).status_code == 403
    report.status = "resolved"
    await db_session.commit()
    assert (await async_client.post(f"/api/v1/reports/{report.id}/seen", headers=report_world["headers"]["a"])).status_code == 409
    assert (await async_client.put(f"/api/v1/reports/{report.id}/taken", headers=report_world["headers"]["a"])).status_code == 409
