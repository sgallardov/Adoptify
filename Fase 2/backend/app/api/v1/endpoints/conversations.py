from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import exists, select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.auth import get_current_user
from app.db.database import get_db
from app.models.adoption_application import AdoptionApplication
from app.models.adoption_form import AdoptionFormRequest
from app.models.animal import Animal
from app.models.animal_favorite import AnimalFavorite
from app.models.conversation import Conversation, Message
from app.models.foster_application import FosterApplication
from app.models.foundation import Foundation
from app.models.user import User
from app.schemas.conversation import ConversationCreate, ConversationOut, LastMessage, MessageCreate, MessageOut, QuestionInfo
from app.services.adoption_questionnaire import start_questionnaire

router = APIRouter()

# Sin after_id se entregan los últimos mensajes; el sondeo pide solo los nuevos con after_id
MESSAGES_PAGE = 200
NOT_FOUND = "Conversación no encontrada."


def _is_foundation_side(user: User, conversation: Conversation) -> bool:
    return user.role != "adopter" and user.foundation_id is not None and user.foundation_id == conversation.foundation_id


def _is_participant(user: User, conversation: Conversation) -> bool:
    return conversation.user_id == user.id or _is_foundation_side(user, conversation)


def _question_info(message: Message, form: AdoptionFormRequest | None, index: int | None) -> QuestionInfo | None:
    """Datos de una pregunta automática, para que la app muestre los botones de respuesta."""
    if message.kind != "question" or form is None or index is None:
        return None
    question = form.questions[index]
    return QuestionInfo(
        form_id=form.id, animal_id=form.animal_id, index=index, total=len(form.questions),
        kind=question["kind"], options=question.get("options") or [], required=question.get("required", True),
    )


def _message_out(
    message: Message,
    conversation: Conversation,
    current_user: User,
    form: AdoptionFormRequest | None = None,
    question_index: int | None = None,
) -> MessageOut:
    return MessageOut(
        id=message.id,
        body=message.body,
        created_at=message.created_at,
        # Los mensajes automáticos (sin remitente) se muestran como de la fundación
        from_foundation=message.sender_user_id != conversation.user_id,
        mine=message.sender_user_id is not None and message.sender_user_id == current_user.id,
        kind=message.kind,
        question=_question_info(message, form, question_index),
    )


async def question_indexes(db: AsyncSession, messages: list[Message]) -> tuple[dict[int, AdoptionFormRequest], dict[int, int]]:
    """Cuestionarios de los mensajes y la posición de cada pregunta automática.

    La posición de una pregunta es cuántas preguntas del mismo cuestionario hubo antes que ella
    en el chat (se cuentan también las que quedaron fuera de esta página).
    """
    form_ids = {message.form_request_id for message in messages if message.form_request_id is not None}
    if not form_ids:
        return {}, {}
    forms = {
        form.id: form
        for form in (await db.execute(select(AdoptionFormRequest).where(AdoptionFormRequest.id.in_(form_ids)))).scalars()
    }
    questions = (await db.execute(
        select(Message.id, Message.form_request_id)
        .where(Message.form_request_id.in_(form_ids), Message.kind == "question")
        .order_by(Message.id)
    )).all()
    indexes: dict[int, int] = {}
    seen: dict[int, int] = {}
    for message_id, form_id in questions:
        indexes[message_id] = seen.get(form_id, 0)
        seen[form_id] = indexes[message_id] + 1
    return forms, indexes


def messages_out(
    messages: list[Message], conversation: Conversation, current_user: User,
    forms: dict[int, AdoptionFormRequest], indexes: dict[int, int],
) -> list[MessageOut]:
    return [
        _message_out(message, conversation, current_user, forms.get(message.form_request_id), indexes.get(message.id))
        for message in messages
    ]


async def _linked_to_foundation(db: AsyncSession, user_id: int, foundation_id: int) -> bool:
    """La persona dio like a un animal de la fundación, postuló a uno de ellos o postuló como hogar temporal."""
    liked = exists().where(
        AnimalFavorite.user_id == user_id,
        AnimalFavorite.animal_id == Animal.id,
        Animal.foundation_id == foundation_id,
    )
    applied = exists().where(
        AdoptionApplication.adopter_id == user_id, AdoptionApplication.foundation_id == foundation_id
    )
    # La postulación a hogar temporal es general: la ven todas las fundaciones
    fosters = exists().where(FosterApplication.user_id == user_id)
    return bool((await db.execute(select(liked | applied | fosters))).scalar())


async def _conversation_out(db: AsyncSession, conversation: Conversation) -> ConversationOut:
    foundation = await db.get(Foundation, conversation.foundation_id)
    user = await db.get(User, conversation.user_id)
    last = (await db.execute(
        select(Message).where(Message.conversation_id == conversation.id).order_by(Message.id.desc()).limit(1)
    )).scalar_one_or_none()
    return ConversationOut(
        id=conversation.id,
        foundation_id=conversation.foundation_id,
        foundation_name=foundation.name if foundation else "",
        user_id=conversation.user_id,
        user_name=user.full_name if user else "",
        created_at=conversation.created_at,
        last_message=None if last is None else LastMessage(
            body=last.body, created_at=last.created_at, from_foundation=last.sender_user_id != conversation.user_id
        ),
    )


async def _own_conversation(db: AsyncSession, conversation_id: int, current_user: User) -> Conversation:
    """404 tanto si no existe como si la cuenta no participa: así no se revela que existe."""
    try:
        conversation = await db.get(Conversation, conversation_id)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo cargar la conversación.") from exc
    if conversation is None or not _is_participant(current_user, conversation):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=NOT_FOUND)
    return conversation


@router.post(
    "",
    response_model=ConversationOut,
    status_code=status.HTTP_201_CREATED,
    summary="Abrir un chat con un adoptante",
    description=(
        "Solo fundaciones. La persona debe haber dado like a un animal de la fundación, postulado a uno de ellos "
        "o postulado como hogar temporal. Si la conversación ya existe se devuelve la misma con 200. "
        "Con animal_id (botón Conversar de los interesados de esa mascota) empieza en el chat el cuestionario "
        "de adopción de la fundación, una sola vez por persona y mascota (HU-G3)."
    ),
    responses={
        200: {"description": "La conversación ya existía"},
        403: {"description": "La cuenta no es de fundación o la persona no está vinculada a ella"},
        404: {"description": "No existe un adoptante con ese id, o la mascota no es de la fundación"},
    },
)
async def open_conversation(
    payload: ConversationCreate,
    response: Response,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "foundation" or current_user.foundation_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Solo una fundación puede abrir una conversación.")
    foundation_id = current_user.foundation_id
    try:
        target = await db.get(User, payload.user_id)
        if target is None or target.role != "adopter":
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No encontramos a esa persona.")
        animal = None
        if payload.animal_id is not None:
            animal = await db.get(Animal, payload.animal_id)
            if animal is None or animal.foundation_id != foundation_id:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No encontramos esa mascota en tu fundación.")
        conversation = (await db.execute(
            select(Conversation).where(Conversation.foundation_id == foundation_id, Conversation.user_id == target.id)
        )).scalar_one_or_none()
        if conversation is not None:
            response.status_code = status.HTTP_200_OK
        else:
            if not await _linked_to_foundation(db, target.id, foundation_id):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Solo puedes conversar con personas interesadas en tus animales o postuladas.",
                )
            conversation = Conversation(foundation_id=foundation_id, user_id=target.id)
            db.add(conversation)
            await db.flush()
        if animal is not None:
            await start_questionnaire(db, conversation, animal, first_name=target.full_name.split()[0])
        await db.commit()
        await db.refresh(conversation)
    except IntegrityError:
        # Otro socio de la fundación la abrió (o empezó el cuestionario) al mismo tiempo: se devuelve esa
        await db.rollback()
        conversation = (await db.execute(
            select(Conversation).where(Conversation.foundation_id == foundation_id, Conversation.user_id == payload.user_id)
        )).scalar_one()
        response.status_code = status.HTTP_200_OK
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo abrir la conversación.") from exc
    return await _conversation_out(db, conversation)


@router.get(
    "",
    response_model=list[ConversationOut],
    summary="Mis conversaciones",
    description="La fundación ve las de su fundación; el adoptante, las suyas. Primero las con actividad más reciente.",
)
async def list_conversations(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if current_user.role == "adopter":
        condition = Conversation.user_id == current_user.id
    elif current_user.foundation_id is not None:
        condition = Conversation.foundation_id == current_user.foundation_id
    else:
        return []
    try:
        conversations = (await db.execute(select(Conversation).where(condition))).scalars().all()
        items = [await _conversation_out(db, conversation) for conversation in conversations]
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudieron cargar las conversaciones.") from exc
    items.sort(key=lambda item: item.last_message.created_at if item.last_message else item.created_at, reverse=True)
    return items


@router.get(
    "/{conversation_id}/messages",
    response_model=list[MessageOut],
    summary="Mensajes de una conversación",
    description=(
        f"Solo los dos participantes; cualquier otra cuenta recibe 404. Sin after_id entrega los últimos "
        f"{MESSAGES_PAGE}; con after_id, solo los posteriores (para el sondeo)."
    ),
    responses={404: {"description": "No existe o la cuenta no participa"}},
)
async def list_messages(
    conversation_id: int,
    after_id: int | None = Query(None, ge=0, description="Entrega solo los mensajes con id mayor"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conversation = await _own_conversation(db, conversation_id, current_user)
    query = select(Message).where(Message.conversation_id == conversation.id)
    if after_id is not None:
        query = query.where(Message.id > after_id)
    try:
        messages = list(reversed((await db.execute(query.order_by(Message.id.desc()).limit(MESSAGES_PAGE))).scalars().all()))
        forms, indexes = await question_indexes(db, messages)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudieron cargar los mensajes.") from exc
    return messages_out(messages, conversation, current_user, forms, indexes)


@router.post(
    "/{conversation_id}/messages",
    response_model=MessageOut,
    status_code=status.HTTP_201_CREATED,
    summary="Enviar un mensaje",
    description="Solo los dos participantes. El texto va de 1 a 1000 caracteres.",
    responses={404: {"description": "No existe o la cuenta no participa"}, 422: {"description": "Mensaje vacío o muy largo"}},
)
async def send_message(
    conversation_id: int,
    payload: MessageCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conversation = await _own_conversation(db, conversation_id, current_user)
    message = Message(conversation_id=conversation.id, sender_user_id=current_user.id, body=payload.body)
    db.add(message)
    try:
        await db.commit()
        await db.refresh(message)
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo enviar el mensaje.") from exc
    return _message_out(message, conversation, current_user)
