"""Cuestionario de adopción por chat (HU-G3).

Cuando la fundación aprieta "Conversar" junto a un interesado en una mascota, el chat le hace
las preguntas de la fundación una a una. Cada respuesta se guarda y llega la siguiente pregunta;
al terminar, la fundación ve la postulación ("Ver postulación") y la acepta o la rechaza.
"""
from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.adoption_form import AdoptionFormQuestion, AdoptionFormRequest
from app.models.animal import Animal
from app.models.conversation import Conversation, Message
from app.models.foundation import Foundation
from app.schemas.adoption_form import MAX_ANSWER_LENGTH, AnswerValue, FormQuestion

# Preguntas sugeridas por Adoptify: toda fundación parte con ellas y puede editarlas en Mi fundación.
# Las 7 primeras filtran (flagged_answers = lo que no cumple); la última da contexto para conversar.
DEFAULT_QUESTIONS: list[FormQuestion] = [
    FormQuestion(label="¿Eres mayor de 18 años?", kind="yes_no", flagged_answers=[False]),
    FormQuestion(label="¿Todas las personas de tu hogar están de acuerdo con adoptar?", kind="yes_no", flagged_answers=[False]),
    FormQuestion(
        label="¿Tu vivienda permite tener mascotas?", kind="choice",
        options=["Es propia", "Arriendo y el contrato lo permite", "Arriendo y no lo permite"],
        flagged_answers=["Arriendo y no lo permite"],
    ),
    FormQuestion(
        label="¿Tu hogar tiene cierre seguro (rejas, y mallas en ventanas y balcones si es gato)?",
        kind="yes_no", flagged_answers=[False],
    ),
    FormQuestion(
        label=(
            "¿Te comprometes a cubrir sus gastos (alimento, vacunas y veterinario) y a esterilizarla, "
            "ponerle microchip e inscribirla según la Ley Cholito?"
        ),
        kind="yes_no", flagged_answers=[False],
    ),
    FormQuestion(
        label="Si te cambias de casa o ya no puedes cuidarla, ¿qué harías?", kind="choice",
        options=["Me la llevo", "La devuelvo a la fundación", "Le busco otro hogar por mi cuenta"],
        flagged_answers=["Le busco otro hogar por mi cuenta"],
    ),
    FormQuestion(label="¿Aceptas una visita previa y seguimiento después de la adopción?", kind="yes_no", flagged_answers=[False]),
    FormQuestion(label="¿Por qué quieres adoptar a esta mascota y qué experiencia tienes con mascotas?", kind="text"),
]

FINISHED = "¡Gracias por responder! Enviamos tus respuestas a la fundación; te contaremos por aquí cómo sigue tu postulación."


def intro_message(first_name: str, animal_name: str, total: int) -> str:
    return (
        f"¡Hola, {first_name}! Gracias por tu interés en {animal_name}. Antes de seguir, te haremos "
        f"{total} {'pregunta corta' if total == 1 else 'preguntas cortas'} para conocerte. Responde aquí mismo."
    )


async def foundation_questions(db: AsyncSession, foundation: Foundation) -> list[FormQuestion]:
    """Las preguntas propias de la fundación, o las sugeridas si todavía no guardó las suyas."""
    if not foundation.adoption_form_customized:
        return list(DEFAULT_QUESTIONS)
    rows = (await db.execute(
        select(AdoptionFormQuestion)
        .where(AdoptionFormQuestion.foundation_id == foundation.id)
        .order_by(AdoptionFormQuestion.position)
    )).scalars().all()
    return [
        FormQuestion(
            label=row.label, kind=row.kind, options=row.options or [], required=row.required,
            flagged_answers=row.flagged_answers or [],
        )
        for row in rows
    ]


def format_answer(answer: AnswerValue) -> str:
    """Cómo se ve la respuesta en el chat y en la postulación."""
    if answer is None:
        return "Prefiero no responder"
    if isinstance(answer, bool):
        return "Sí" if answer else "No"
    return answer


def clean_answer(question: FormQuestion, answer: AnswerValue) -> AnswerValue:
    """Valida una respuesta contra su pregunta (mismas reglas que la versión de formulario completo)."""
    if isinstance(answer, str):
        answer = answer.strip() or None
    if answer is None:
        if question.required:
            raise HTTPException(status_code=422, detail="Esta pregunta es obligatoria.")
        return None
    if question.kind == "yes_no" and not isinstance(answer, bool):
        raise HTTPException(status_code=422, detail="Responde sí o no.")
    if question.kind == "choice" and answer not in question.options:
        raise HTTPException(status_code=422, detail="Elige una de las alternativas.")
    if question.kind == "text" and (not isinstance(answer, str) or len(answer) > MAX_ANSWER_LENGTH):
        raise HTTPException(status_code=422, detail=f"La respuesta debe ser un texto de hasta {MAX_ANSWER_LENGTH} caracteres.")
    return answer


def is_flagged(question: FormQuestion, answer: AnswerValue) -> bool:
    """True si la respuesta es una de las que la fundación marcó como "No cumple"."""
    if answer is None:
        return False
    # bool y str se comparan por separado: en Python True == 1, pero nunca "Sí" == True
    return any(type(item) is type(answer) and item == answer for item in question.flagged_answers)


def questions_of(request: AdoptionFormRequest) -> list[FormQuestion]:
    return [FormQuestion(**question) for question in request.questions]


def flagged_list(request: AdoptionFormRequest) -> list[bool]:
    questions = questions_of(request)
    return [is_flagged(question, answer) for question, answer in zip(questions, request.answers)]


def question_message(request: AdoptionFormRequest, index: int) -> Message:
    """Pregunta automática: sin remitente, se muestra como de la fundación."""
    return Message(
        conversation_id=request.conversation_id, sender_user_id=None, body=request.questions[index]["label"],
        kind="question", form_request_id=request.id,
    )


async def start_questionnaire(
    db: AsyncSession, conversation: Conversation, animal: Animal, first_name: str
) -> AdoptionFormRequest | None:
    """Empieza el cuestionario de esa mascota si corresponde. No hace commit.

    No hace nada si la persona ya tiene (o tuvo) uno para esa mascota, si está respondiendo otro
    en la misma conversación (las preguntas irían mezcladas) o si la fundación no tiene preguntas.
    """
    existing = (await db.execute(
        select(AdoptionFormRequest).where(AdoptionFormRequest.conversation_id == conversation.id)
    )).scalars().all()
    if any(request.animal_id == animal.id or not request.completed for request in existing):
        return None
    foundation = await db.get(Foundation, conversation.foundation_id)
    questions = await foundation_questions(db, foundation) if foundation else []
    if not questions:
        return None
    request = AdoptionFormRequest(
        conversation_id=conversation.id, animal_id=animal.id,
        questions=[question.model_dump() for question in questions], answers=[],
    )
    db.add(request)
    await db.flush()
    db.add(Message(
        conversation_id=conversation.id, sender_user_id=None,
        body=intro_message(first_name, animal.name, len(questions)), kind="text",
    ))
    db.add(question_message(request, 0))
    return request


def record_answer(request: AdoptionFormRequest, answer: AnswerValue, sender_user_id: int) -> list[Message]:
    """Guarda la respuesta a la pregunta actual y prepara la siguiente (o el cierre). No hace commit."""
    questions = questions_of(request)
    index = len(request.answers)
    answer = clean_answer(questions[index], answer)
    # Se reasigna la lista para que SQLAlchemy detecte el cambio en la columna JSON
    request.answers = [*request.answers, answer]
    messages = [Message(
        conversation_id=request.conversation_id, sender_user_id=sender_user_id, body=format_answer(answer),
        kind="answer", form_request_id=request.id,
    )]
    if len(request.answers) < len(questions):
        messages.append(question_message(request, len(request.answers)))
    else:
        request.answered_at = datetime.now(timezone.utc)
        messages.append(Message(conversation_id=request.conversation_id, sender_user_id=None, body=FINISHED, kind="text"))
    return messages
