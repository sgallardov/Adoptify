"""Chat entre fundación y adoptante (HU-G2): quién abre, quién lee y el límite de 1000 caracteres."""
import random
import uuid

import pytest
from geoalchemy2.elements import WKTElement
from httpx import AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.animal import Animal
from app.models.animal_favorite import AnimalFavorite
from app.models.foster_application import FosterApplication
from app.models.foundation import Foundation
from app.models.user import User

PASSWORD = "ClaveSegura123"
URL = "/api/v1/conversations"


def unique_rut() -> str:
    return f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}"


@pytest.fixture
async def world(async_client: AsyncClient, db_session: AsyncSession):
    """Dos fundaciones con una cuenta y un animal cada una, y tres adoptantes:
    uno que dio like al animal de A, uno que postuló a hogar temporal y uno sin vínculo."""
    tag = uuid.uuid4().hex[:8]
    foundations = [
        Foundation(name=f"Test Chat {n}", rut=unique_rut(), email=f"test_chat_{n}_{tag}@adoptify.cl") for n in ("A", "B")
    ]
    db_session.add_all(foundations)
    await db_session.flush()

    def user(label: str, role: str, foundation_id: int | None = None) -> User:
        return User(
            email=f"test_chat_{label}_{tag}@adoptify.cl", rut=unique_rut(), hashed_password=hash_password(PASSWORD),
            full_name=f"Test {label}", role=role, foundation_id=foundation_id, preferences={},
        )

    users = {
        "a": user("a", "foundation", foundations[0].id),
        "a2": user("a2", "foundation", foundations[0].id),
        "b": user("b", "foundation", foundations[1].id),
        "liker": user("liker", "adopter"),
        "foster": user("foster", "adopter"),
        "stranger": user("stranger", "adopter"),
    }
    db_session.add_all(users.values())
    animals = [
        Animal(
            foundation_id=f.id, name=f"Test Chat Animal {n}", species="gato", gender="hembra", size="pequeño",
            energy_level=2, location=WKTElement("POINT(-70.6 -33.4)", srid=4326),
        )
        for f, n in zip(foundations, ("A", "B"))
    ]
    db_session.add_all(animals)
    await db_session.flush()
    db_session.add(AnimalFavorite(user_id=users["liker"].id, animal_id=animals[0].id))
    db_session.add(FosterApplication(
        user_id=users["foster"].id, species="ambos", sizes=["pequeño"], space="casa_patio", max_animals=1,
        max_days=15, availability="Desde ya", phone="+56 9 1111 2222", address="Calle Prueba 123",
    ))
    await db_session.commit()

    headers = {}
    for key, u in users.items():
        response = await async_client.post("/api/v1/auth/login", json={"email": u.email, "password": PASSWORD})
        headers[key] = {"Authorization": f"Bearer {response.json()['access_token']}"}
    yield {"foundations": foundations, "users": users, "headers": headers, "animals": animals}

    await db_session.execute(delete(Animal).where(Animal.foundation_id.in_([f.id for f in foundations])))
    await db_session.execute(delete(User).where(User.id.in_([u.id for u in users.values()])))
    await db_session.execute(delete(Foundation).where(Foundation.id.in_([f.id for f in foundations])))
    await db_session.commit()


async def open_chat(client: AsyncClient, world: dict, foundation: str, adopter: str):
    return await client.post(URL, json={"user_id": world["users"][adopter].id}, headers=world["headers"][foundation])


async def test_foundation_opens_chat_with_someone_who_liked_its_animal(async_client, world):
    response = await open_chat(async_client, world, "a", "liker")
    assert response.status_code == 201
    body = response.json()
    assert body["foundation_id"] == world["foundations"][0].id
    assert body["user_id"] == world["users"]["liker"].id
    assert body["user_name"] == "Test liker"
    assert body["last_message"] is None
    # Nunca se exponen datos de contacto del adoptante
    assert not {"email", "rut", "phone"}.intersection(body)


async def test_foundation_opens_chat_with_foster_applicant(async_client, world):
    # La postulación a hogar temporal es general: cualquier fundación puede escribirle
    assert (await open_chat(async_client, world, "a", "foster")).status_code == 201
    assert (await open_chat(async_client, world, "b", "foster")).status_code == 201


async def test_opening_twice_returns_the_same_conversation(async_client, world):
    first = await open_chat(async_client, world, "a", "liker")
    # Otro socio de la misma fundación llega a la misma conversación
    second = await open_chat(async_client, world, "a2", "liker")
    assert second.status_code == 200
    assert second.json()["id"] == first.json()["id"]


async def test_foundation_cannot_open_chat_with_unlinked_person(async_client, world):
    assert (await open_chat(async_client, world, "a", "stranger")).status_code == 403
    # El like fue a un animal de A: la fundación B no puede usarlo para escribirle
    assert (await open_chat(async_client, world, "b", "liker")).status_code == 403


async def test_open_with_unknown_or_non_adopter_user_is_404(async_client, world):
    response = await async_client.post(URL, json={"user_id": 999_999_999}, headers=world["headers"]["a"])
    assert response.status_code == 404
    response = await async_client.post(URL, json={"user_id": world["users"]["b"].id}, headers=world["headers"]["a"])
    assert response.status_code == 404


async def test_adopter_cannot_open_conversations(async_client, world):
    response = await async_client.post(
        URL, json={"user_id": world["users"]["foster"].id}, headers=world["headers"]["liker"]
    )
    assert response.status_code == 403


async def test_chat_requires_login(async_client, world):
    assert (await async_client.get(URL)).status_code == 401
    assert (await async_client.post(URL, json={"user_id": 1})).status_code == 401


async def test_both_participants_exchange_messages(async_client, world):
    conversation_id = (await open_chat(async_client, world, "a", "liker")).json()["id"]
    messages_url = f"{URL}/{conversation_id}/messages"

    sent = await async_client.post(messages_url, json={"body": "  Hola, ¿sigues interesada?  "}, headers=world["headers"]["a"])
    assert sent.status_code == 201
    assert sent.json()["body"] == "Hola, ¿sigues interesada?"
    assert sent.json()["from_foundation"] is True and sent.json()["mine"] is True

    # El adoptante responde en la conversación existente
    reply = await async_client.post(messages_url, json={"body": "¡Sí!"}, headers=world["headers"]["liker"])
    assert reply.status_code == 201
    assert reply.json()["from_foundation"] is False

    # Otro socio de la fundación ve todo, y los suyos no salen como "míos"
    listed = await async_client.get(messages_url, headers=world["headers"]["a2"])
    assert listed.status_code == 200
    assert [(m["body"], m["from_foundation"], m["mine"]) for m in listed.json()] == [
        ("Hola, ¿sigues interesada?", True, False),
        ("¡Sí!", False, False),
    ]

    # El sondeo pide solo lo nuevo
    newer = await async_client.get(messages_url, params={"after_id": sent.json()["id"]}, headers=world["headers"]["a"])
    assert [m["body"] for m in newer.json()] == ["¡Sí!"]


async def test_only_participants_see_or_write_others_get_404(async_client, world):
    conversation_id = (await open_chat(async_client, world, "a", "liker")).json()["id"]
    messages_url = f"{URL}/{conversation_id}/messages"
    for outsider in ("b", "stranger", "foster"):
        headers = world["headers"][outsider]
        assert (await async_client.get(messages_url, headers=headers)).status_code == 404
        assert (await async_client.post(messages_url, json={"body": "hola"}, headers=headers)).status_code == 404
    # Una conversación inexistente responde igual
    assert (await async_client.get(f"{URL}/999999999/messages", headers=world["headers"]["a"])).status_code == 404


async def test_list_shows_only_own_conversations_with_last_message(async_client, world):
    with_liker = (await open_chat(async_client, world, "a", "liker")).json()["id"]
    with_foster = (await open_chat(async_client, world, "a", "foster")).json()["id"]
    await async_client.post(f"{URL}/{with_liker}/messages", json={"body": "Último"}, headers=world["headers"]["liker"])

    foundation_list = (await async_client.get(URL, headers=world["headers"]["a"])).json()
    # La de actividad más reciente primero
    assert [c["id"] for c in foundation_list] == [with_liker, with_foster]
    assert foundation_list[0]["last_message"]["body"] == "Último"
    assert foundation_list[0]["last_message"]["from_foundation"] is False

    assert [c["id"] for c in (await async_client.get(URL, headers=world["headers"]["liker"])).json()] == [with_liker]
    assert (await async_client.get(URL, headers=world["headers"]["b"])).json() == []
    assert (await async_client.get(URL, headers=world["headers"]["stranger"])).json() == []


async def test_message_length_limit_is_1000_characters(async_client, world):
    conversation_id = (await open_chat(async_client, world, "a", "liker")).json()["id"]
    messages_url = f"{URL}/{conversation_id}/messages"
    headers = world["headers"]["a"]
    assert (await async_client.post(messages_url, json={"body": "a" * 1000}, headers=headers)).status_code == 201
    assert (await async_client.post(messages_url, json={"body": "a" * 1001}, headers=headers)).status_code == 422
    assert (await async_client.post(messages_url, json={"body": ""}, headers=headers)).status_code == 422
    assert (await async_client.post(messages_url, json={"body": "   "}, headers=headers)).status_code == 422
