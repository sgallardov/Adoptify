from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.auth import get_current_user
from app.db.database import get_db
from app.models.foundation import Foundation
from app.models.foundation_member import FoundationMember
from app.models.user import User
from app.schemas.foundation_member import MemberCreate, MemberResponse, MemberUpdate, PublicMemberResponse

router = APIRouter()

NOT_ALLOWED = "Solo una cuenta de fundación puede gestionar sus socios."


def _check_role(user: User) -> None:
    if user.role == "admin":
        return
    if user.role != "foundation" or user.foundation_id is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=NOT_ALLOWED)


async def _get_member(member_id: int, user: User, db: AsyncSession) -> FoundationMember:
    """Busca el socio y comprueba que la cuenta puede gestionarlo (admin: todos; fundación: solo los suyos)."""
    _check_role(user)
    try:
        member = await db.get(FoundationMember, member_id)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar el socio.") from exc
    if member is None:
        raise HTTPException(status_code=404, detail="No encontramos ese socio.")
    if user.role != "admin" and member.foundation_id != user.foundation_id:
        raise HTTPException(status_code=403, detail="Ese socio pertenece a otra fundación.")
    return member


@router.get(
    "/me/members",
    response_model=list[MemberResponse],
    summary="Listar los socios de mi fundación (privado)",
    description="Incluye el aporte. Admin: ve todos (filtra con `foundation_id`).",
    responses={401: {"description": "Se requiere iniciar sesión"}, 403: {"description": "La cuenta no es de fundación"}},
)
async def list_my_members(
    foundation_id: int | None = Query(None, description="Solo admin: filtrar por fundación"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _check_role(current_user)
    statement = select(FoundationMember).order_by(FoundationMember.joined_at.desc(), FoundationMember.id.desc())
    if current_user.role == "admin":
        if foundation_id is not None:
            statement = statement.where(FoundationMember.foundation_id == foundation_id)
    else:
        statement = statement.where(FoundationMember.foundation_id == current_user.foundation_id)
    try:
        return (await db.execute(statement)).scalars().all()
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar los socios.") from exc


@router.post(
    "/me/members",
    response_model=MemberResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Agregar un socio a mi fundación",
    description="Solo registro: no hay pasarela ni cobros. Un admin debe indicar `foundation_id`.",
    responses={403: {"description": "La cuenta no es de fundación"}, 422: {"description": "Datos inválidos"}},
)
async def create_member(
    payload: MemberCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _check_role(current_user)
    data = payload.model_dump(exclude={"foundation_id"})
    if current_user.role == "admin":
        if payload.foundation_id is None:
            raise HTTPException(status_code=422, detail="Indica la fundación (foundation_id) del socio.")
        foundation_id = payload.foundation_id
    else:
        foundation_id = current_user.foundation_id
    try:
        if current_user.role == "admin" and await db.get(Foundation, foundation_id) is None:
            raise HTTPException(status_code=404, detail="No encontramos esa fundación.")
        member = FoundationMember(foundation_id=foundation_id, **data)
        db.add(member)
        await db.commit()
        await db.refresh(member)
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar el socio.") from exc
    return member


@router.put(
    "/me/members/{member_id}",
    response_model=MemberResponse,
    summary="Editar un socio de mi fundación",
    responses={403: {"description": "El socio es de otra fundación"}, 404: {"description": "No existe"}},
)
async def update_member(
    member_id: int,
    payload: MemberUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    member = await _get_member(member_id, current_user, db)
    for key, value in payload.model_dump().items():
        setattr(member, key, value)
    try:
        await db.commit()
        await db.refresh(member)
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar el socio.") from exc
    return member


@router.delete(
    "/me/members/{member_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Borrar un socio de mi fundación",
    responses={403: {"description": "El socio es de otra fundación"}, 404: {"description": "No existe"}},
)
async def delete_member(
    member_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    member = await _get_member(member_id, current_user, db)
    try:
        await db.delete(member)
        await db.commit()
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo borrar el socio.") from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get(
    "/{foundation_id}/members/public",
    response_model=list[PublicMemberResponse],
    summary="Socios públicos de una fundación (Nuestros socios)",
    description="Público. Solo nombre y fecha de ingreso de los socios marcados como públicos; nunca el aporte.",
)
async def list_public_members(foundation_id: int, db: AsyncSession = Depends(get_db)):
    statement = (
        select(FoundationMember)
        .where(FoundationMember.foundation_id == foundation_id, FoundationMember.is_public.is_(True))
        .order_by(FoundationMember.joined_at.desc(), FoundationMember.id.desc())
    )
    try:
        return (await db.execute(statement)).scalars().all()
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar los socios.") from exc
