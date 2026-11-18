"""Formulario de adopción configurable enviado por chat (HU-G3)."""
from httpx import AsyncClient

from tests.test_conversations import open_chat, world  # noqa: F401  (world es un fixture)

FORM_URL = "/api/v1/foundations/me/adoption-form"
QUESTIONS = [
    {"label": "¿Vives en casa o departamento?", "kind": "choice", "options": ["Casa", "Departamento"]},
    {"label": "¿Todos en tu hogar están de acuerdo?", "kind": "yes_no"},
    {"label": "Cuéntanos de tus mascotas anteriores", "kind": "text", "required": False},
]


async def configure(client: AsyncClient, world: dict, foundation: str = "a"):
    return await client.put(FORM_URL, json={"questions": QUESTIONS}, headers=world["headers"][foundation])


async def chat_with_form(client: AsyncClient, world: dict) -> tuple[int, dict]:
    await configure(client, world)
    conversation_id = (await open_chat(client, world, "a", "liker")).json()["id"]
    sent = await client.post(f"/api/v1/conversations/{conversation_id}/form", headers=world["headers"]["a"])
    assert sent.status_code == 201
    return conversation_id, sent.json()


async def test_foundation_configures_its_own_form(async_client, world):
    headers = world["headers"]
    assert (await async_client.get(FORM_URL, headers=headers["a"])).json() == {"questions": []}
    saved = await configure(async_client, world)
    assert saved.status_code == 200
    # Otro socio de la misma fundación ve las mismas preguntas, en orden; otra fundación no
    questions = (await async_client.get(FORM_URL, headers=headers["a2"])).json()["questions"]
    assert [q["label"] for q in questions] == [q["label"] for q in QUESTIONS]
    assert questions[0]["options"] == ["Casa", "Departamento"]
    assert questions[2]["required"] is False
    assert (await async_client.get(FORM_URL, headers=headers["b"])).json() == {"questions": []}


async def test_only_foundations_have_a_form(async_client, world):
    assert (await async_client.get(FORM_URL, headers=world["headers"]["liker"])).status_code == 403
    assert (await configure(async_client, world, "liker")).status_code == 403


async def test_invalid_questions_are_rejected(async_client, world):
    headers = world["headers"]["a"]
    for question in (
        {"label": "Elige", "kind": "choice", "options": ["Solo una"]},
        {"label": "Elige", "kind": "choice", "options": ["Sí", "sí"]},
        {"label": "¿Patio?", "kind": "yes_no", "options": ["Sí", "No"]},
        {"label": "   ", "kind": "text"},
    ):
        assert (await async_client.put(FORM_URL, json={"questions": [question]}, headers=headers)).status_code == 422
    too_many = [{"label": f"Pregunta {n}", "kind": "text"} for n in range(21)]
    assert (await async_client.put(FORM_URL, json={"questions": too_many}, headers=headers)).status_code == 422


async def test_cannot_send_an_empty_form(async_client, world):
    conversation_id = (await open_chat(async_client, world, "a", "liker")).json()["id"]
    response = await async_client.post(f"/api/v1/conversations/{conversation_id}/form", headers=world["headers"]["a"])
    assert response.status_code == 409


async def test_foundation_sends_form_and_adopter_answers(async_client, world):
    conversation_id, sent = await chat_with_form(async_client, world)
    assert sent["kind"] == "form"
    assert sent["form"]["answers"] is None
    form_id = sent["form"]["id"]

    # Editar el formulario después no cambia el que ya se envió
    await async_client.put(FORM_URL, json={"questions": [{"label": "Otra", "kind": "text"}]}, headers=world["headers"]["a"])
    adopter_view = (await async_client.get(
        f"/api/v1/conversations/{conversation_id}/messages", headers=world["headers"]["liker"]
    )).json()
    assert [q["label"] for q in adopter_view[-1]["form"]["questions"]] == [q["label"] for q in QUESTIONS]

    answers_url = f"/api/v1/conversations/{conversation_id}/forms/{form_id}/answers"
    answered = await async_client.post(
        answers_url, json={"answers": ["Casa", True, "  "]}, headers=world["headers"]["liker"]
    )
    assert answered.status_code == 201
    assert answered.json()["kind"] == "form_answers"
    assert answered.json()["form"]["answers"] == ["Casa", True, None]

    # La fundación lo ve con el sondeo (after_id) y en la vista previa de la conversación
    new = (await async_client.get(
        f"/api/v1/conversations/{conversation_id}/messages",
        params={"after_id": sent["id"]}, headers=world["headers"]["a2"],
    )).json()
    assert [m["kind"] for m in new] == ["form_answers"]
    assert new[0]["form"]["answered_at"] is not None
    preview = (await async_client.get("/api/v1/conversations", headers=world["headers"]["a"])).json()[0]
    assert preview["last_message"]["body"] == "Respondí el formulario de adopción."

    # Las respuestas no se pueden cambiar
    again = await async_client.post(answers_url, json={"answers": ["Departamento", False, None]}, headers=world["headers"]["liker"])
    assert again.status_code == 409


async def test_answers_are_validated_against_each_question(async_client, world):
    conversation_id, sent = await chat_with_form(async_client, world)
    url = f"/api/v1/conversations/{conversation_id}/forms/{sent['form']['id']}/answers"
    headers = world["headers"]["liker"]
    for answers in (
        ["Casa", True],  # falta una respuesta
        [None, True, None],  # obligatoria sin responder
        ["Parcela", True, None],  # alternativa inexistente
        ["Casa", "sí", None],  # sí/no debe ser booleano
        ["Casa", True, "x" * 1001],  # texto muy largo
    ):
        assert (await async_client.post(url, json={"answers": answers}, headers=headers)).status_code == 422
    # Nada quedó guardado: todavía se puede responder
    assert (await async_client.post(url, json={"answers": ["Casa", False, None]}, headers=headers)).status_code == 201


async def test_only_the_right_side_can_send_or_answer(async_client, world):
    conversation_id, sent = await chat_with_form(async_client, world)
    form_url = f"/api/v1/conversations/{conversation_id}/form"
    answers_url = f"/api/v1/conversations/{conversation_id}/forms/{sent['form']['id']}/answers"
    body = {"answers": ["Casa", True, None]}
    # El adoptante no envía formularios y la fundación no responde el suyo
    assert (await async_client.post(form_url, headers=world["headers"]["liker"])).status_code == 403
    assert (await async_client.post(answers_url, json=body, headers=world["headers"]["a"])).status_code == 403
    # Quien no participa recibe 404, igual que en el chat
    assert (await async_client.post(form_url, headers=world["headers"]["b"])).status_code == 404
    assert (await async_client.post(answers_url, json=body, headers=world["headers"]["stranger"])).status_code == 404
    # Un formulario de otra conversación tampoco existe aquí
    other = (await open_chat(async_client, world, "a", "foster")).json()["id"]
    wrong = f"/api/v1/conversations/{other}/forms/{sent['form']['id']}/answers"
    assert (await async_client.post(wrong, json=body, headers=world["headers"]["foster"])).status_code == 404
