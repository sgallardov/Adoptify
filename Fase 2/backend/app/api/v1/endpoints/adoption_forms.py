"""Formulario de requisitos de adopción (HU-G3): cada fundación configura sus preguntas,
lo envía por el chat y el adoptante responde una sola vez."""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.auth import get_current_user
from app.api.v1.endpoints.conversations import _is_foundation_side, _message_out, _own_conversation
from app.db.database import get_db
from app.models.adoption_form import AdoptionFormQuestion, AdoptionFormRequest
from app.models.conversation import Message
from app.models.user import User
from app.schemas.adoption_form import MAX_ANSWER_LENGTH, AdoptionForm, AnswerValue, FormAnswers, FormQuestion
from app.schemas.conversation import MessageOut

router = APIRouter()

FORM_SENT = "Te enviamos nuestro formulario de adopción."
FORM_ANSWERED = "Respondí el formulario de adopción."


def _foundation_id(user: User) -> int:
    if user.role == "adopter" or user.foundation_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo una fundación tiene formulario de adopción.")
    return user.foundation_id


async def _questions(db: AsyncSession, foundation_id: int) -> list[FormQuestion]:
    rows = (await db.execute(
        select(AdoptionFormQuestion)
        .where(AdoptionFormQuestion.foundation_id == foundation_id)
        .order_by(AdoptionFormQuestion.position)
    )).scalars().all()
    return [FormQuestion(label=row.label, kind=row.kind, options=row.options or [], required=row.required) for row in rows]


def _clean_answers(questions: list[FormQuestion], answers: list[AnswerValue]) -> list[AnswerValue]:
    """Valida cada respuesta contra su pregunta. 422 con un mensaje que nombra la pregunta."""
    if len(answers) != len(questions):
        raise HTTPException(status_code=422, detail="Debes enviar una respuesta por cada pregunta.")
    cleaned: list[AnswerValue] = []
    for question, answer in zip(questions, answers):
        if isinstance(answer, str):
            answer = answer.strip() or None
        if answer is None:
            if question.required:
                raise HTTPException(status_code=422, detail=f"Falta responder: {question.label}")
        elif question.kind == "yes_no" and not isinstance(answer, bool):
            raise HTTPException(status_code=422, detail=f"Responde sí o no: {question.label}")
        elif question.kind == "choice" and answer not in question.options:
            raise HTTPException(status_code=422, detail=f"Elige una de las alternativas: {question.label}")
        elif question.kind == "text" and (not isinstance(answer, str) or len(answer) > MAX_ANSWER_LENGTH):
            raise HTTPException(
                status_code=422, detail=f"La respuesta debe ser un texto de hasta {MAX_ANSWER_LENGTH} caracteres: {question.label}"
            )
        cleaned.append(answer)
    return cleaned


@router.get(
    "/foundations/me/adoption-form",
    response_model=AdoptionForm,
    summary="Formulario de adopción de mi fundación",
    description="Las preguntas que la fundación envía por chat a quien quiere adoptar. Sin preguntas, la lista viene vacía.",
)
async def get_adoption_form(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    foundation_id = _foundation_id(current_user)
    try:
        return AdoptionForm(questions=await _questions(db, foundation_id))
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo cargar el formulario.") from exc


@router.put(
    "/foundations/me/adoption-form",
    response_model=AdoptionForm,
    summary="Guardar el formulario de adopción",
    description=(
        "Reemplaza todas las preguntas (máximo 20), en el orden recibido. Los formularios ya enviados "
        "no cambian: cada envío guarda su propia copia."
    ),
    responses={403: {"description": "La cuenta no es de fundación"}},
)
async def save_adoption_form(
    payload: AdoptionForm, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    foundation_id = _foundation_id(current_user)
    try:
        await db.execute(delete(AdoptionFormQuestion).where(AdoptionFormQuestion.foundation_id == foundation_id))
        db.add_all([
            AdoptionFormQuestion(
                foundation_id=foundation_id, position=position, label=question.label, kind=question.kind,
                options=question.options or None, required=question.required,
            )
            for position, question in enumerate(payload.questions)
        ])
        await db.commit()
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar el formulario.") from exc
    return payload


@router.post(
    "/conversations/{conversation_id}/form",
    response_model=MessageOut,
    status_code=status.HTTP_201_CREATED,
    summary="Enviar el formulario de adopción por el chat",
    description="Solo la fundación de la conversación. Crea un mensaje de tipo 'form' con una copia de las preguntas actuales.",
    responses={
        403: {"description": "Quien envía no es la fundación de la conversación"},
        404: {"description": "No existe o la cuenta no participa"},
        409: {"description": "La fundación todavía no configuró preguntas"},
    },
)
async def send_form(
    conversation_id: int, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    conversation = await _own_conversation(db, conversation_id, current_user)
    if not _is_foundation_side(current_user, conversation):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo la fundación puede enviar su formulario.")
    try:
        questions = await _questions(db, conversation.foundation_id)
        if not questions:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Primero configura las preguntas de tu formulario en Mi fundación.",
            )
        form = AdoptionFormRequest(conversation_id=conversation.id, questions=[q.model_dump() for q in questions])
        db.add(form)
        await db.flush()
        message = Message(
            conversation_id=conversation.id, sender_user_id=current_user.id, body=FORM_SENT, kind="form", form_request_id=form.id
        )
        db.add(message)
        await db.commit()
        await db.refresh(message)
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo enviar el formulario.") from exc
    return _message_out(message, conversation, current_user, form)


@router.post(
    "/conversations/{conversation_id}/forms/{form_id}/answers",
    response_model=MessageOut,
    status_code=status.HTTP_201_CREATED,
    summary="Responder el formulario de adopción",
    description=(
        "Solo el adoptante de la conversación y una sola vez: las respuestas no se pueden modificar. "
        "Crea un mensaje de tipo 'form_answers' para que la fundación lo vea en su próximo sondeo."
    ),
    responses={
        403: {"description": "Quien responde no es el adoptante de la conversación"},
        404: {"description": "La conversación o el formulario no existen"},
        409: {"description": "El formulario ya fue respondido"},
        422: {"description": "Falta una respuesta obligatoria o no corresponde al tipo de pregunta"},
    },
)
async def answer_form(
    conversation_id: int,
    form_id: int,
    payload: FormAnswers,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conversation = await _own_conversation(db, conversation_id, current_user)
    if conversation.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo quien recibió el formulario puede responderlo.")
    try:
        # FOR UPDATE: dos envíos simultáneos no pueden responder dos veces
        form = (await db.execute(
            select(AdoptionFormRequest)
            .where(AdoptionFormRequest.id == form_id, AdoptionFormRequest.conversation_id == conversation.id)
            .with_for_update()
        )).scalar_one_or_none()
        if form is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Formulario no encontrado.")
        if form.answers is not None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ya respondiste este formulario.")
        form.answers = _clean_answers([FormQuestion(**q) for q in form.questions], payload.answers)
        form.answered_at = datetime.now(timezone.utc)
        message = Message(
            conversation_id=conversation.id, sender_user_id=current_user.id, body=FORM_ANSWERED,
            kind="form_answers", form_request_id=form.id,
        )
        db.add(message)
        await db.commit()
        await db.refresh(message)
    except HTTPException:
        await db.rollback()
        raise
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudieron guardar tus respuestas.") from exc
    return _message_out(message, conversation, current_user, form)
