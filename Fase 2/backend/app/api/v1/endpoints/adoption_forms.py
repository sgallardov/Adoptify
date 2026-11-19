"""Cuestionario de adopción (HU-G3).

Cada fundación tiene sus preguntas (o las sugeridas por Adoptify). Al apretar "Conversar" junto a
un interesado en una mascota, el chat le hace las preguntas una a una (ver conversations.py y
services/adoption_questionnaire.py). Aquí: editar las preguntas, responder la pregunta actual,
ver la postulación y aceptarla o rechazarla.
"""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.auth import get_current_user
from app.api.v1.endpoints.conversations import _is_foundation_side, _own_conversation, messages_out, question_indexes
from app.db.database import get_db
from app.models.adoption_form import AdoptionFormQuestion, AdoptionFormRequest
from app.models.animal import Animal
from app.models.conversation import Conversation, Message
from app.models.foundation import Foundation
from app.models.user import User
from app.schemas.adoption_form import AdoptionForm, AdoptionFormOut, AnswerIn, DecisionIn, QuestionnaireOut
from app.schemas.conversation import MessageOut
from app.services.adoption_questionnaire import flagged_list, foundation_questions, questions_of, record_answer

router = APIRouter()

NOT_FOUND = "Postulación no encontrada."


def _foundation_id(user: User) -> int:
    if user.role == "adopter" or user.foundation_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo una fundación tiene cuestionario de adopción.")
    return user.foundation_id


async def _foundation(db: AsyncSession, user: User) -> Foundation:
    foundation = await db.get(Foundation, _foundation_id(user))
    if foundation is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Fundación no encontrada.")
    return foundation


@router.get(
    "/foundations/me/adoption-form",
    response_model=AdoptionFormOut,
    summary="Cuestionario de adopción de mi fundación",
    description=(
        "Las preguntas que el chat le hace a quien se interesa en una mascota. Mientras la fundación no "
        "guarde las suyas, son las sugeridas por Adoptify (customized = false)."
    ),
)
async def get_adoption_form(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        foundation = await _foundation(db, current_user)
        return AdoptionFormOut(questions=await foundation_questions(db, foundation), customized=foundation.adoption_form_customized)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo cargar el cuestionario.") from exc


@router.put(
    "/foundations/me/adoption-form",
    response_model=AdoptionFormOut,
    summary="Guardar el cuestionario de adopción",
    description=(
        "Reemplaza todas las preguntas (máximo 20), en el orden recibido. Sin preguntas, \"Conversar\" solo abre "
        "el chat. Los cuestionarios ya empezados no cambian: cada uno guarda su propia copia."
    ),
    responses={403: {"description": "La cuenta no es de fundación"}},
)
async def save_adoption_form(
    payload: AdoptionForm, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    try:
        foundation = await _foundation(db, current_user)
        await db.execute(delete(AdoptionFormQuestion).where(AdoptionFormQuestion.foundation_id == foundation.id))
        db.add_all([
            AdoptionFormQuestion(
                foundation_id=foundation.id, position=position, label=question.label, kind=question.kind,
                options=question.options or None, required=question.required,
                flagged_answers=question.flagged_answers or None,
            )
            for position, question in enumerate(payload.questions)
        ])
        foundation.adoption_form_customized = True
        await db.commit()
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar el cuestionario.") from exc
    return AdoptionFormOut(questions=payload.questions, customized=True)


@router.delete(
    "/foundations/me/adoption-form",
    response_model=AdoptionFormOut,
    summary="Volver a las preguntas sugeridas",
    description="Borra las preguntas propias de la fundación y vuelve a usar las sugeridas por Adoptify.",
    responses={403: {"description": "La cuenta no es de fundación"}},
)
async def reset_adoption_form(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        foundation = await _foundation(db, current_user)
        await db.execute(delete(AdoptionFormQuestion).where(AdoptionFormQuestion.foundation_id == foundation.id))
        foundation.adoption_form_customized = False
        await db.commit()
        return AdoptionFormOut(questions=await foundation_questions(db, foundation), customized=False)
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo restablecer el cuestionario.") from exc


@router.post(
    "/conversations/{conversation_id}/forms/{form_id}/answer",
    response_model=list[MessageOut],
    status_code=status.HTTP_201_CREATED,
    summary="Responder la pregunta actual del cuestionario",
    description=(
        "Solo el adoptante de la conversación. Responde la pregunta pendiente (sí o no, una alternativa o texto; "
        "null salta una opcional) y devuelve los mensajes nuevos: su respuesta y la siguiente pregunta, o el "
        "cierre si era la última. Las respuestas no se pueden modificar."
    ),
    responses={
        403: {"description": "Quien responde no es el adoptante de la conversación"},
        404: {"description": "La conversación o el cuestionario no existen"},
        409: {"description": "El cuestionario ya se respondió completo"},
        422: {"description": "La respuesta no corresponde a la pregunta"},
    },
)
async def answer_question(
    conversation_id: int,
    form_id: int,
    payload: AnswerIn,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conversation = await _own_conversation(db, conversation_id, current_user)
    if conversation.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo quien postula puede responder el cuestionario.")
    try:
        # FOR UPDATE: dos toques seguidos no pueden responder dos veces la misma pregunta
        form = (await db.execute(
            select(AdoptionFormRequest)
            .where(AdoptionFormRequest.id == form_id, AdoptionFormRequest.conversation_id == conversation.id)
            .with_for_update()
        )).scalar_one_or_none()
        if form is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cuestionario no encontrado.")
        if form.completed:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya respondiste todas las preguntas.")
        messages = record_answer(form, payload.answer, current_user.id)
        db.add_all(messages)
        await db.commit()
        for message in messages:
            await db.refresh(message)
        await db.refresh(form)
        forms, indexes = await question_indexes(db, messages)
    except HTTPException:
        await db.rollback()
        raise
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar tu respuesta.") from exc
    return messages_out(messages, conversation, current_user, forms, indexes)


async def _own_request(db: AsyncSession, request_id: int, current_user: User, lock: bool = False):
    """Postulación de la fundación de la cuenta; 404 si es de otra (no se revela que existe)."""
    foundation_id = _foundation_id(current_user)
    statement = (
        select(AdoptionFormRequest, Conversation, Animal, User)
        .join(Conversation, Conversation.id == AdoptionFormRequest.conversation_id)
        .join(Animal, Animal.id == AdoptionFormRequest.animal_id)
        .join(User, User.id == Conversation.user_id)
        .where(AdoptionFormRequest.id == request_id, Conversation.foundation_id == foundation_id)
    )
    if lock:
        statement = statement.with_for_update(of=AdoptionFormRequest)
    row = (await db.execute(statement)).one_or_none()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=NOT_FOUND)
    return row


def _questionnaire_out(form: AdoptionFormRequest, conversation: Conversation, animal: Animal, user: User) -> QuestionnaireOut:
    return QuestionnaireOut(
        id=form.id, conversation_id=conversation.id, animal_id=animal.id, animal_name=animal.name,
        user_id=user.id, full_name=user.full_name, questions=questions_of(form), answers=form.answers,
        flagged=flagged_list(form), completed=form.completed, answered_at=form.answered_at,
        decision=form.decision, decided_at=form.decided_at, created_at=form.created_at,
    )


@router.get(
    "/adoption-form-requests/{request_id}",
    response_model=QuestionnaireOut,
    summary="Ver una postulación",
    description=(
        "Solo la fundación de la mascota: preguntas, respuestas (sin datos de contacto ni RUT) y cuáles no "
        "cumplen lo esperado. Otra fundación recibe 404."
    ),
    responses={403: {"description": "La cuenta no es de fundación"}, 404: {"description": "No existe o es de otra fundación"}},
)
async def get_questionnaire(request_id: int, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        form, conversation, animal, user = await _own_request(db, request_id, current_user)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo cargar la postulación.") from exc
    return _questionnaire_out(form, conversation, animal, user)


@router.post(
    "/adoption-form-requests/{request_id}/decision",
    response_model=QuestionnaireOut,
    summary="Aceptar o rechazar una postulación",
    description=(
        "Solo la fundación de la mascota y cuando la persona respondió todo. Envía el mensaje por el chat "
        "y deja la decisión registrada; no se puede cambiar después."
    ),
    responses={
        403: {"description": "La cuenta no es de fundación"},
        404: {"description": "No existe o es de otra fundación"},
        409: {"description": "Faltan respuestas o la postulación ya tiene una decisión"},
    },
)
async def decide_questionnaire(
    request_id: int,
    payload: DecisionIn,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        form, conversation, animal, user = await _own_request(db, request_id, current_user, lock=True)
        if not form.completed:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="La persona todavía no termina de responder.")
        if form.decision is not None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Esta postulación ya tiene una decisión.")
        form.decision = payload.decision
        form.decided_at = datetime.now(timezone.utc)
        db.add(Message(conversation_id=conversation.id, sender_user_id=current_user.id, body=payload.message, kind="text"))
        await db.commit()
        await db.refresh(form)
    except HTTPException:
        await db.rollback()
        raise
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar la decisión.") from exc
    return _questionnaire_out(form, conversation, animal, user)
