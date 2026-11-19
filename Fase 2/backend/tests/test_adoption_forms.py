"""Cuestionario de adopción por chat (HU-G3): preguntas sugeridas o propias, una pregunta a la vez,
una sola vez por persona y mascota, y la postulación que la fundación acepta o rechaza."""
from httpx import AsyncClient

from app.services.adoption_questionnaire import DEFAULT_QUESTIONS, FINISHED
from tests.test_conversations import URL, world  # noqa: F401  (world es un fixture)

FORM_URL = "/api/v1/foundations/me/adoption-form"
REQUESTS_URL = "/api/v1/adoption-form-requests"
QUESTIONS = [
    {"label": "¿Vives en casa o departamento?", "kind": "choice", "options": ["Casa", "Departamento"],
     "flagged_answers": ["Departamento"]},
    {"label": "¿Todos en tu hogar están de acuerdo?", "kind": "yes_no", "flagged_answers": [False]},
    {"label": "Cuéntanos de tus mascotas anteriores", "kind": "text", "required": False},
]


async def configure(client: AsyncClient, world: dict, questions=QUESTIONS, foundation: str = "a"):
    return await client.put(FORM_URL, json={"questions": questions}, headers=world["headers"][foundation])


async def converse(client: AsyncClient, world: dict, adopter: str = "liker", animal: int = 0, foundation: str = "a"):
    """El botón "Conversar" de los interesados de una mascota."""
    payload = {"user_id": world["users"][adopter].id, "animal_id": world["animals"][animal].id}
    return await client.post(URL, json=payload, headers=world["headers"][foundation])


async def messages(client: AsyncClient, world: dict, conversation_id: int, who: str = "liker") -> list[dict]:
    response = await client.get(f"{URL}/{conversation_id}/messages", headers=world["headers"][who])
    assert response.status_code == 200
    return response.json()


async def answer(client: AsyncClient, world: dict, conversation_id: int, form_id: int, value, who: str = "liker"):
    return await client.post(
        f"{URL}/{conversation_id}/forms/{form_id}/answer", json={"answer": value}, headers=world["headers"][who],
    )


async def pending_question(client: AsyncClient, world: dict, conversation_id: int) -> dict:
    return [m for m in await messages(client, world, conversation_id) if m["kind"] == "question"][-1]


async def interested(client: AsyncClient, world: dict, animal: int = 0) -> list[dict]:
    animal_id = world["animals"][animal].id
    response = await client.get(f"/api/v1/animals/{animal_id}/interested", headers=world["headers"]["a"])
    return response.json()["interested"]


# ---------- Preguntas de la fundación ----------

async def test_new_foundations_start_with_the_suggested_questions(async_client, world):
    body = (await async_client.get(FORM_URL, headers=world["headers"]["a"])).json()
    assert body["customized"] is False
    assert len(body["questions"]) == 8
    assert body["questions"][0] == {
        "label": "¿Eres mayor de 18 años?", "kind": "yes_no", "options": [], "required": True, "flagged_answers": [False],
    }
    assert body["questions"][2]["flagged_answers"] == ["Arriendo y no lo permite"]
    assert body["questions"][7]["kind"] == "text"


async def test_foundation_saves_its_own_questions_and_can_go_back(async_client, world):
    headers = world["headers"]
    saved = await configure(async_client, world)
    assert saved.status_code == 200
    assert saved.json()["customized"] is True
    # Otro socio de la misma fundación ve las mismas; otra fundación sigue con las sugeridas
    mine = (await async_client.get(FORM_URL, headers=headers["a2"])).json()
    assert [q["label"] for q in mine["questions"]] == [q["label"] for q in QUESTIONS]
    assert mine["questions"][0]["flagged_answers"] == ["Departamento"]
    assert (await async_client.get(FORM_URL, headers=headers["b"])).json()["customized"] is False

    reset = await async_client.delete(FORM_URL, headers=headers["a"])
    assert reset.status_code == 200
    assert reset.json()["customized"] is False
    assert len(reset.json()["questions"]) == len(DEFAULT_QUESTIONS)


async def test_only_foundations_have_questions(async_client, world):
    assert (await async_client.get(FORM_URL, headers=world["headers"]["liker"])).status_code == 403
    assert (await configure(async_client, world, foundation="liker")).status_code == 403


async def test_invalid_questions_are_rejected(async_client, world):
    for question in (
        {"label": "Elige", "kind": "choice", "options": ["Solo una"]},
        {"label": "Elige", "kind": "choice", "options": ["Sí", "sí"]},
        {"label": "¿Patio?", "kind": "yes_no", "options": ["Sí", "No"]},
        {"label": "   ", "kind": "text"},
        # Lo que no cumple debe ser una respuesta posible, y al menos una alternativa debe cumplir
        {"label": "¿Patio?", "kind": "yes_no", "flagged_answers": ["No"]},
        {"label": "¿Patio?", "kind": "yes_no", "flagged_answers": [True, False]},
        {"label": "Elige", "kind": "choice", "options": ["A", "B"], "flagged_answers": ["C"]},
        {"label": "Elige", "kind": "choice", "options": ["A", "B"], "flagged_answers": ["A", "B"]},
        {"label": "Cuéntanos", "kind": "text", "flagged_answers": ["nada"]},
    ):
        response = await configure(async_client, world, [question])
        assert response.status_code == 422, question
    too_many = [{"label": f"Pregunta {n}", "kind": "text"} for n in range(21)]
    assert (await configure(async_client, world, too_many)).status_code == 422


# ---------- "Conversar" empieza el cuestionario ----------

async def test_converse_starts_the_questionnaire_with_the_first_question(async_client, world):
    response = await converse(async_client, world)
    assert response.status_code == 201
    chat = await messages(async_client, world, response.json()["id"])
    assert [m["kind"] for m in chat] == ["text", "question"]
    assert "Test Chat Animal A" in chat[0]["body"] and "8 preguntas cortas" in chat[0]["body"]
    question = chat[1]
    assert question["body"] == "¿Eres mayor de 18 años?"
    assert question["from_foundation"] is True and question["mine"] is False
    assert question["question"]["index"] == 0 and question["question"]["total"] == 8
    assert question["question"]["kind"] == "yes_no"
    assert question["question"]["animal_id"] == world["animals"][0].id


async def test_without_animal_converse_only_opens_the_chat(async_client, world):
    response = await async_client.post(URL, json={"user_id": world["users"]["liker"].id}, headers=world["headers"]["a"])
    assert response.status_code == 201
    assert await messages(async_client, world, response.json()["id"]) == []


async def test_without_questions_converse_works_as_before(async_client, world):
    await configure(async_client, world, [])
    response = await converse(async_client, world)
    assert response.status_code == 201
    assert await messages(async_client, world, response.json()["id"]) == []


async def test_the_same_person_never_gets_the_questionnaire_twice(async_client, world):
    first = await converse(async_client, world)
    again = await converse(async_client, world, foundation="a2")
    assert again.status_code == 200
    assert again.json()["id"] == first.json()["id"]
    chat = await messages(async_client, world, first.json()["id"])
    assert [m["kind"] for m in chat].count("question") == 1


async def test_cannot_start_a_questionnaire_for_another_foundations_animal(async_client, world):
    response = await converse(async_client, world, animal=1)
    assert response.status_code == 404


# ---------- Responder una pregunta a la vez ----------

async def test_adopter_answers_one_by_one_and_each_answer_brings_the_next(async_client, world):
    await configure(async_client, world)
    conversation_id = (await converse(async_client, world)).json()["id"]
    question = await pending_question(async_client, world, conversation_id)
    form_id = question["question"]["form_id"]

    first = await answer(async_client, world, conversation_id, form_id, "Departamento")
    assert first.status_code == 201
    answer_message, next_question = first.json()
    assert answer_message["kind"] == "answer" and answer_message["body"] == "Departamento" and answer_message["mine"] is True
    assert next_question["kind"] == "question" and next_question["question"]["index"] == 1

    second = await answer(async_client, world, conversation_id, form_id, True)
    assert second.json()[0]["body"] == "Sí"
    # La última es opcional: null la salta y llega el cierre
    last = await answer(async_client, world, conversation_id, form_id, None)
    assert [m["body"] for m in last.json()] == ["Prefiero no responder", FINISHED]

    again = await answer(async_client, world, conversation_id, form_id, "Casa")
    assert again.status_code == 409


async def test_answers_are_checked_against_the_current_question(async_client, world):
    await configure(async_client, world)
    conversation_id = (await converse(async_client, world)).json()["id"]
    form_id = (await pending_question(async_client, world, conversation_id))["question"]["form_id"]
    assert (await answer(async_client, world, conversation_id, form_id, "Parcela")).status_code == 422
    assert (await answer(async_client, world, conversation_id, form_id, None)).status_code == 422
    await answer(async_client, world, conversation_id, form_id, "Casa")
    wrong_kind = await answer(async_client, world, conversation_id, form_id, "sí")
    assert wrong_kind.status_code == 422
    assert wrong_kind.json()["detail"] == "Responde sí o no."


async def test_only_the_adopter_answers(async_client, world):
    conversation_id = (await converse(async_client, world)).json()["id"]
    form_id = (await pending_question(async_client, world, conversation_id))["question"]["form_id"]
    assert (await answer(async_client, world, conversation_id, form_id, True, who="a")).status_code == 403
    assert (await answer(async_client, world, conversation_id, form_id, True, who="stranger")).status_code == 404


async def test_question_positions_survive_reloading_the_chat(async_client, world):
    conversation_id = (await converse(async_client, world)).json()["id"]
    form_id = (await pending_question(async_client, world, conversation_id))["question"]["form_id"]
    for value in (True, True, "Es propia"):
        await answer(async_client, world, conversation_id, form_id, value)
    questions = [m for m in await messages(async_client, world, conversation_id, who="a") if m["kind"] == "question"]
    assert [q["question"]["index"] for q in questions] == [0, 1, 2, 3]
    # El sondeo con after_id también trae la posición correcta
    after = questions[-2]["id"]
    polled = (await async_client.get(f"{URL}/{conversation_id}/messages", params={"after_id": after}, headers=world["headers"]["liker"])).json()
    assert [m["question"]["index"] for m in polled if m["kind"] == "question"] == [3]


# ---------- La postulación en Interesados ----------

async def answer_all(client: AsyncClient, world: dict, values: list) -> tuple[int, int]:
    await configure(client, world)
    conversation_id = (await converse(client, world)).json()["id"]
    form_id = (await pending_question(client, world, conversation_id))["question"]["form_id"]
    for value in values:
        assert (await answer(client, world, conversation_id, form_id, value)).status_code == 201
    return conversation_id, form_id


async def test_interested_list_shows_progress_and_then_the_application(async_client, world):
    assert (await interested(async_client, world))[0]["questionnaire"] is None
    await configure(async_client, world)
    conversation_id = (await converse(async_client, world)).json()["id"]
    form_id = (await pending_question(async_client, world, conversation_id))["question"]["form_id"]
    await answer(async_client, world, conversation_id, form_id, "Casa")
    progress = (await interested(async_client, world))[0]["questionnaire"]
    assert progress == {"id": form_id, "answered": 1, "total": 3, "completed": False, "flagged": 0, "decision": None}

    await answer(async_client, world, conversation_id, form_id, False)
    await answer(async_client, world, conversation_id, form_id, "Tuve un gato 10 años")
    done = (await interested(async_client, world))[0]["questionnaire"]
    assert done["completed"] is True and done["flagged"] == 1


async def test_foundation_sees_the_application_with_what_does_not_meet(async_client, world):
    _, form_id = await answer_all(async_client, world, ["Departamento", True, "Tuve un gato 10 años"])
    response = await async_client.get(f"{REQUESTS_URL}/{form_id}", headers=world["headers"]["a"])
    assert response.status_code == 200
    body = response.json()
    assert body["animal_name"] == "Test Chat Animal A"
    assert body["full_name"] == "Test liker"
    assert body["answers"] == ["Departamento", True, "Tuve un gato 10 años"]
    assert body["flagged"] == [True, False, False]
    assert body["completed"] is True and body["decision"] is None
    # Sin datos de contacto
    assert "email" not in body and "rut" not in body
    # Otra fundación no la ve; un adoptante tampoco
    assert (await async_client.get(f"{REQUESTS_URL}/{form_id}", headers=world["headers"]["b"])).status_code == 404
    assert (await async_client.get(f"{REQUESTS_URL}/{form_id}", headers=world["headers"]["liker"])).status_code == 403


async def test_accepting_sends_the_message_and_cannot_be_changed(async_client, world):
    conversation_id, form_id = await answer_all(async_client, world, ["Casa", True, None])
    accepted = await async_client.post(
        f"{REQUESTS_URL}/{form_id}/decision",
        json={"decision": "accepted", "message": "  ¡Buenas noticias! Queremos avanzar.  "},
        headers=world["headers"]["a"],
    )
    assert accepted.status_code == 200
    assert accepted.json()["decision"] == "accepted"
    last = (await messages(async_client, world, conversation_id))[-1]
    assert last["body"] == "¡Buenas noticias! Queremos avanzar." and last["from_foundation"] is True
    assert (await interested(async_client, world))[0]["questionnaire"]["decision"] == "accepted"

    change = await async_client.post(
        f"{REQUESTS_URL}/{form_id}/decision", json={"decision": "rejected", "message": "No"}, headers=world["headers"]["a2"],
    )
    assert change.status_code == 409


async def test_cannot_decide_before_all_answers_arrive(async_client, world):
    await configure(async_client, world)
    conversation_id = (await converse(async_client, world)).json()["id"]
    form_id = (await pending_question(async_client, world, conversation_id))["question"]["form_id"]
    response = await async_client.post(
        f"{REQUESTS_URL}/{form_id}/decision", json={"decision": "rejected", "message": "Gracias"}, headers=world["headers"]["a"],
    )
    assert response.status_code == 409
    assert response.json()["detail"] == "La persona todavía no termina de responder."


async def test_decision_needs_a_message_and_a_valid_choice(async_client, world):
    _, form_id = await answer_all(async_client, world, ["Casa", True, None])
    headers = world["headers"]["a"]
    for payload in ({"decision": "accepted", "message": "   "}, {"decision": "tal vez", "message": "Hola"}):
        assert (await async_client.post(f"{REQUESTS_URL}/{form_id}/decision", json=payload, headers=headers)).status_code == 422
    other = await async_client.post(
        f"{REQUESTS_URL}/{form_id}/decision", json={"decision": "rejected", "message": "Gracias"}, headers=world["headers"]["b"],
    )
    assert other.status_code == 404


async def test_editing_questions_later_does_not_change_a_started_questionnaire(async_client, world):
    await configure(async_client, world)
    conversation_id = (await converse(async_client, world)).json()["id"]
    form_id = (await pending_question(async_client, world, conversation_id))["question"]["form_id"]
    await configure(async_client, world, [{"label": "Otra", "kind": "text"}])
    await answer(async_client, world, conversation_id, form_id, "Casa")
    following = await pending_question(async_client, world, conversation_id)
    assert following["body"] == "¿Todos en tu hogar están de acuerdo?"
