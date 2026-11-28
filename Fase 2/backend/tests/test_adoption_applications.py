"""Postulaciones de adopción (HU-AC): el adoptante ve y retira las suyas; la fundación nunca ve las retiradas."""
from httpx import AsyncClient

from tests.test_conversations import world  # noqa: F401  (world es un fixture)

URL = "/api/v1/adoption-applications"
PROFILE = {
    "housing_type": "departamento", "has_kids": "no", "has_pets": "si", "hours_alone": "2_5",
    "wanted_species": ["gato"], "wanted_sizes": ["pequeño"],
}
GONE = "La postulación ya no existe; quizá la retiraron."


async def apply(client: AsyncClient, world: dict, who: str = "liker", animal: int = 0):
    return await client.post(
        f"{URL}/animals/{world['animals'][animal].id}", json={"profile": PROFILE}, headers=world["headers"][who],
    )


async def mine(client: AsyncClient, world: dict, who: str = "liker") -> list[dict]:
    response = await client.get(f"{URL}/mine", headers=world["headers"][who])
    assert response.status_code == 200
    return response.json()


async def test_mine_lists_only_own_applications_newest_first(async_client, world):
    first = (await apply(async_client, world, animal=0)).json()
    second = (await apply(async_client, world, animal=1)).json()
    await apply(async_client, world, who="stranger", animal=0)

    items = await mine(async_client, world)
    assert [i["id"] for i in items] == [second["id"], first["id"]]
    assert items[0]["animal_name"] == "Test Chat Animal B"
    assert {"animal_id", "animal_photo_url", "foundation_name", "status", "created_at"} <= set(items[0])
    assert len(await mine(async_client, world, "stranger")) == 1


async def test_withdraw_hides_it_from_mine_and_from_the_foundation(async_client, world):
    application = (await apply(async_client, world)).json()
    seen = await async_client.get(f"{URL}/foundation", headers=world["headers"]["a"])
    assert [i["id"] for i in seen.json()] == [application["id"]]

    response = await async_client.delete(f"{URL}/{application['id']}", headers=world["headers"]["liker"])
    assert response.status_code == 204
    assert await mine(async_client, world) == []
    seen = await async_client.get(f"{URL}/foundation", headers=world["headers"]["a"])
    assert seen.json() == []


async def test_rejected_can_be_withdrawn_but_approved_cannot(async_client, world):
    rejected = (await apply(async_client, world, animal=0)).json()
    approved = (await apply(async_client, world, animal=1)).json()
    await async_client.patch(f"{URL}/{rejected['id']}/status", json={"status": "rejected"}, headers=world["headers"]["a"])
    await async_client.patch(f"{URL}/{approved['id']}/status", json={"status": "approved"}, headers=world["headers"]["b"])

    assert (await async_client.delete(f"{URL}/{rejected['id']}", headers=world["headers"]["liker"])).status_code == 204
    blocked = await async_client.delete(f"{URL}/{approved['id']}", headers=world["headers"]["liker"])
    assert blocked.status_code == 409
    assert "Contacta a la fundación" in blocked.json()["detail"]
    assert [i["status"] for i in await mine(async_client, world)] == ["approved"]


async def test_someone_else_cannot_withdraw_it(async_client, world):
    application = (await apply(async_client, world)).json()
    for who in ("stranger", "a"):
        response = await async_client.delete(f"{URL}/{application['id']}", headers=world["headers"][who])
        assert response.status_code == 404
    assert len(await mine(async_client, world)) == 1


async def test_withdrawing_twice_or_a_missing_one_is_404(async_client, world):
    application = (await apply(async_client, world)).json()
    await async_client.delete(f"{URL}/{application['id']}", headers=world["headers"]["liker"])
    assert (await async_client.delete(f"{URL}/{application['id']}", headers=world["headers"]["liker"])).status_code == 404
    assert (await async_client.delete(f"{URL}/0", headers=world["headers"]["liker"])).status_code == 404


async def test_foundation_deciding_on_a_withdrawn_application_gets_404(async_client, world):
    application = (await apply(async_client, world)).json()
    await async_client.delete(f"{URL}/{application['id']}", headers=world["headers"]["liker"])

    response = await async_client.patch(
        f"{URL}/{application['id']}/status", json={"status": "approved"}, headers=world["headers"]["a"],
    )
    assert response.status_code == 404
    assert response.json()["detail"] == GONE


async def test_animal_can_be_applied_to_again_after_withdrawing(async_client, world):
    application = (await apply(async_client, world)).json()
    await async_client.delete(f"{URL}/{application['id']}", headers=world["headers"]["liker"])

    again = await apply(async_client, world)
    assert again.status_code == 201
    assert again.json()["status"] == "submitted"
    assert [i["id"] for i in await mine(async_client, world)] == [again.json()["id"]]
    # Con una postulación abierta, repetir sigue siendo un conflicto
    assert (await apply(async_client, world)).status_code == 409


async def test_foundation_cannot_withdraw_or_list_mine(async_client, world):
    assert (await async_client.get(f"{URL}/mine", headers=world["headers"]["a"])).status_code == 403
