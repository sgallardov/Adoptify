from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.exc import SQLAlchemyError

from app.db.database import get_db
from app.main import app
from app.models.animal import Animal


@pytest.fixture
async def animals_client():
    db = AsyncMock()

    async def override_db():
        yield db

    previous = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_db
    try:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            yield client, db
    finally:
        app.dependency_overrides.clear()
        app.dependency_overrides.update(previous)


async def test_animals_returns_public_fields_and_nullable_values(animals_client):
    client, db = animals_client
    result = MagicMock()
    result.scalars.return_value.all.return_value = [Animal(
        id=101, foundation_id=2, name="Prueba API", species="gato",
        breed=None, age_months=None, gender="hembra", size="pequeño",
        energy_level=2, description=None, status="available", photo_url=None,
    )]
    db.execute.return_value = result
    response = await client.get("/api/v1/animals")
    assert response.status_code == 200
    data = response.json()
    assert data[0]["id"] == 101
    assert data[0]["name"] == "Prueba API"
    assert data[0]["foundation_id"] == 2
    assert data[0]["age_months"] is None
    assert data[0]["photo_url"] is None
    assert "location" not in data[0]
    assert "foundation" not in data[0]
    statement = str(db.execute.call_args.args[0])
    assert "ORDER BY animals.id" in statement


async def test_animals_empty_database_returns_empty_list(animals_client):
    client, db = animals_client
    result = MagicMock()
    result.scalars.return_value.all.return_value = []
    db.execute.return_value = result
    response = await client.get("/api/v1/animals")
    assert response.status_code == 200
    assert response.json() == []


async def test_animals_database_failure_returns_503(animals_client):
    client, db = animals_client
    db.execute.side_effect = SQLAlchemyError("private connection details")
    response = await client.get("/api/v1/animals")
    assert response.status_code == 503
    assert "private" not in response.text


async def test_animals_real_database(async_client):
    response = await async_client.get("/api/v1/animals")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert all("name" in animal and "status" in animal for animal in data)
    assert [animal["id"] for animal in data] == sorted(animal["id"] for animal in data)
