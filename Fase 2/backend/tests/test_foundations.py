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


@pytest.fixture
async def foundation_with_animals(db_session: AsyncSession):
    """Fundación de prueba con un animal disponible, uno en proceso y uno adoptado; se elimina al terminar."""
    suffix = uuid.uuid4().hex[:8]
    foundation = Foundation(
        name=f"Fundación Prueba {suffix}",
        rut=f"{random.randint(60_000_000, 99_999_999)}-{random.choice('0123456789K')}",
        email=f"fundacion_{suffix}@adoptify.cl",
        phone="+56 9 1234 5678",
        commune="Ñuñoa",
        description="Rescatamos perros y gatos.",
        location=WKTElement("POINT(-70.6 -33.45)", srid=4326),
    )
    db_session.add(foundation)
    await db_session.flush()

    def animal(name: str, status: str) -> Animal:
        return Animal(
            foundation_id=foundation.id, name=name, species="perro", gender="macho",
            size="mediano", energy_level=3, status=status,
        )

    db_session.add_all([animal("Disponible", "available"), animal("En proceso", "in_process"), animal("Adoptado", "adopted")])
    await db_session.commit()
    yield foundation

    await db_session.execute(delete(Animal).where(Animal.foundation_id == foundation.id))
    await db_session.execute(delete(Foundation).where(Foundation.id == foundation.id))
    await db_session.commit()


async def test_lista_fundaciones_con_solo_sus_animales_disponibles(async_client: AsyncClient, foundation_with_animals):
    response = await async_client.get("/api/v1/foundations")

    assert response.status_code == 200
    found = next(item for item in response.json() if item["id"] == foundation_with_animals.id)
    assert found["name"] == foundation_with_animals.name
    assert found["commune"] == "Ñuñoa"
    assert found["phone"] == "+56 9 1234 5678"
    assert found["latitude"] == pytest.approx(-33.45)
    assert found["longitude"] == pytest.approx(-70.6)
    assert [animal["name"] for animal in found["animals"]] == ["Disponible"]
    assert not {"latitude", "longitude", "distance_km"}.intersection(found["animals"][0])
    assert found["animals"][0]["commune_point"] is None
    assert found["animals"][0]["foundation_name"] == foundation_with_animals.name


async def test_no_expone_rut_ni_geometria(async_client: AsyncClient, foundation_with_animals):
    response = await async_client.get("/api/v1/foundations")

    found = next(item for item in response.json() if item["id"] == foundation_with_animals.id)
    assert "rut" not in found
    assert "location" not in found


async def test_ordena_por_nombre(async_client: AsyncClient, foundation_with_animals):
    data = (await async_client.get("/api/v1/foundations")).json()
    names = [item["name"] for item in data]
    assert names == sorted(names)
    assert all(item["distance_km"] is None for item in data)


async def test_ordena_por_cercania(async_client: AsyncClient, foundation_with_animals):
    # Desde Ñuñoa la fundación de prueba queda a 0 km y es la primera
    data = (await async_client.get("/api/v1/foundations", params={"lat": -33.45, "lng": -70.6})).json()

    assert data[0]["id"] == foundation_with_animals.id
    assert data[0]["distance_km"] == pytest.approx(0)
    distances = [item["distance_km"] for item in data]
    measured = [d for d in distances if d is not None]
    assert measured == sorted(measured)
    # Las fundaciones sin ubicación van al final
    assert distances == measured + [None] * (len(distances) - len(measured))


async def test_distancia_en_km(async_client: AsyncClient, foundation_with_animals):
    # Valparaíso queda a unos 100 km de Ñuñoa
    data = (await async_client.get("/api/v1/foundations", params={"lat": -33.0472, "lng": -71.6127})).json()

    found = next(item for item in data if item["id"] == foundation_with_animals.id)
    assert 95 < found["distance_km"] < 110


@pytest.fixture
async def foundation_account(async_client: AsyncClient, db_session: AsyncSession, foundation_with_animals):
    """Cuenta de fundación ligada a foundation_with_animals y un adoptante, con sus encabezados de sesión."""
    suffix = uuid.uuid4().hex[:8]

    def user(label: str, role: str, foundation_id: int | None = None) -> User:
        return User(
            email=f"test_{label}_{suffix}@adoptify.cl",
            rut=f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}",
            hashed_password=hash_password(PASSWORD), full_name=f"Test {label}", role=role,
            foundation_id=foundation_id, preferences={},
        )

    users = {"foundation": user("perfil", "foundation", foundation_with_animals.id), "adopter": user("adop", "adopter")}
    db_session.add_all(users.values())
    await db_session.commit()

    headers = {}
    for key, account in users.items():
        response = await async_client.post("/api/v1/auth/login", json={"email": account.email, "password": PASSWORD})
        headers[key] = {"Authorization": f"Bearer {response.json()['access_token']}"}
    yield headers

    await db_session.execute(delete(User).where(User.id.in_([u.id for u in users.values()])))
    await db_session.commit()


async def test_fundacion_ve_su_perfil(async_client: AsyncClient, foundation_with_animals, foundation_account):
    response = await async_client.get("/api/v1/foundations/me", headers=foundation_account["foundation"])

    assert response.status_code == 200
    assert response.json()["id"] == foundation_with_animals.id
    assert response.json()["photo_url"] is None


async def test_fundacion_edita_descripcion_y_foto(async_client: AsyncClient, foundation_with_animals, foundation_account):
    photo = "https://images.unsplash.com/photo-1548199973-03cce0bbc87b"
    response = await async_client.put(
        "/api/v1/foundations/me",
        json={"description": "  Rescatamos perros y gatos en Ñuñoa desde 2015.  ", "photo_url": photo},
        headers=foundation_account["foundation"],
    )

    assert response.status_code == 200
    assert response.json()["description"] == "Rescatamos perros y gatos en Ñuñoa desde 2015."
    # Se ve en el listado público (mapa y directorio)
    listed = next(
        item for item in (await async_client.get("/api/v1/foundations")).json() if item["id"] == foundation_with_animals.id
    )
    assert listed["description"] == "Rescatamos perros y gatos en Ñuñoa desde 2015."
    assert listed["photo_url"] == photo


@pytest.mark.parametrize("body", [{}, {"description": "   "}, {"description": "Muy corta"}])
async def test_descripcion_es_obligatoria(async_client: AsyncClient, foundation_account, body):
    response = await async_client.put("/api/v1/foundations/me", json=body, headers=foundation_account["foundation"])

    assert response.status_code == 422


async def test_descripcion_corta_explica_el_minimo(async_client: AsyncClient, foundation_account):
    response = await async_client.put(
        "/api/v1/foundations/me", json={"description": "Muy corta"}, headers=foundation_account["foundation"]
    )

    assert "al menos 20 caracteres" in response.json()["detail"][0]["msg"]


async def test_solo_la_fundacion_edita_su_perfil(async_client: AsyncClient, foundation_account):
    body = {"description": "Una descripción suficientemente larga."}

    assert (await async_client.put("/api/v1/foundations/me", json=body)).status_code == 401
    response = await async_client.put("/api/v1/foundations/me", json=body, headers=foundation_account["adopter"])
    assert response.status_code == 403
    assert response.json()["detail"] == "Solo una cuenta de fundación puede editar su perfil."


async def test_cercania_exige_lat_y_lng(async_client: AsyncClient):
    response = await async_client.get("/api/v1/foundations", params={"lat": -33.45})

    assert response.status_code == 422
    assert response.json()["detail"] == "Para ordenar por cercanía envía lat y lng juntos."
