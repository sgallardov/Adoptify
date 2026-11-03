from fastapi import APIRouter, Depends, HTTPException, Query, status
from geoalchemy2 import Geography
from geoalchemy2.elements import WKTElement
from sqlalchemy import cast, delete, func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.auth import get_current_user, get_optional_user
from app.db.database import get_db
from app.models.report import AbandonedDogReport
from app.models.report_social import ReportComment, ReportLike
from app.models.user import User
from app.schemas.report import NearbyReportResponse, ReportCreate, ReportResponse
from app.schemas.report_social import CommentCreate, CommentResponse, LikesResponse

router = APIRouter()


@router.post(
    "",
    response_model=ReportResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Reportar una mascota abandonada",
    responses={401: {"description": "Se requiere iniciar sesión"}},
)
async def create_report(
    payload: ReportCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    report = AbandonedDogReport(
        reporter_id=current_user.id,
        **payload.model_dump(exclude={"latitude", "longitude"}),
        # PostGIS guarda el punto como (longitud, latitud)
        location=WKTElement(f"POINT({payload.longitude} {payload.latitude})", srid=4326),
    )
    db.add(report)
    try:
        await db.commit()
        await db.refresh(report)
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar el reporte.") from exc
    return report


@router.get(
    "/nearby",
    response_model=list[NearbyReportResponse],
    summary="Buscar reportes activos cerca de un punto",
    description=(
        "Devuelve los reportes de mascotas abandonadas que aún no están resueltos dentro del radio indicado, "
        "ordenados del más cercano al más lejano. La distancia se calcula con PostGIS sobre la superficie "
        "terrestre (geography), en kilómetros."
    ),
)
async def list_nearby_reports(
    lat: float = Query(..., ge=-90, le=90, description="Latitud del punto de búsqueda"),
    lng: float = Query(..., ge=-180, le=180, description="Longitud del punto de búsqueda"),
    radius_km: float = Query(10, gt=0, le=100, description="Radio de búsqueda en kilómetros (máximo 100)"),
    db: AsyncSession = Depends(get_db),
):
    # Se convierte a geography para medir en metros reales y no en grados
    origin = cast(func.ST_SetSRID(func.ST_MakePoint(lng, lat), 4326), Geography)
    report_location = cast(AbandonedDogReport.location, Geography)
    distance_m = func.ST_Distance(report_location, origin).label("distance_m")

    statement = (
        select(AbandonedDogReport, distance_m)
        .where(
            AbandonedDogReport.status != "resolved",
            func.ST_DWithin(report_location, origin, radius_km * 1000),
        )
        .order_by(distance_m, AbandonedDogReport.id)
    )
    try:
        rows = (await db.execute(statement)).all()
    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=503, detail="No se pudo buscar reportes cercanos."
        ) from exc

    return [
        NearbyReportResponse(
            **ReportResponse.model_validate(report).model_dump(),
            distance_km=round(distance / 1000, 2),
        )
        for report, distance in rows
    ]


# --- Comentarios anónimos y "me enteré" de un reporte ---

async def _ensure_report(report_id: int, db: AsyncSession) -> None:
    try:
        exists = (await db.execute(select(AbandonedDogReport.id).where(AbandonedDogReport.id == report_id))).first()
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar el reporte.") from exc
    if exists is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reporte no encontrado.")


async def _likes(report_id: int, user: User | None, db: AsyncSession) -> LikesResponse:
    count = (await db.execute(
        select(func.count()).select_from(ReportLike).where(ReportLike.report_id == report_id)
    )).scalar_one()
    liked = user is not None and (await db.execute(
        select(ReportLike.user_id).where(ReportLike.report_id == report_id, ReportLike.user_id == user.id)
    )).first() is not None
    return LikesResponse(count=count, liked=liked)


@router.get(
    "/{report_id}/comments",
    response_model=list[CommentResponse],
    summary="Comentarios de un reporte",
    description=(
        "Comentarios anónimos del reporte, del más antiguo al más nuevo. Nunca incluye quién los escribió; "
        "con token, `is_mine` indica los propios."
    ),
    responses={404: {"description": "El reporte no existe"}},
)
async def list_comments(
    report_id: int,
    current_user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
):
    await _ensure_report(report_id, db)
    statement = (
        select(ReportComment)
        .where(ReportComment.report_id == report_id)
        .order_by(ReportComment.created_at, ReportComment.id)
    )
    try:
        comments = (await db.execute(statement)).scalars().all()
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo cargar los comentarios.") from exc
    return [
        CommentResponse(
            id=comment.id,
            body=comment.body,
            created_at=comment.created_at,
            is_mine=current_user is not None and comment.author_id == current_user.id,
        )
        for comment in comments
    ]


@router.post(
    "/{report_id}/comments",
    response_model=CommentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Comentar un reporte (anónimo)",
    responses={401: {"description": "Se requiere iniciar sesión"}, 404: {"description": "El reporte no existe"}},
)
async def create_comment(
    report_id: int,
    payload: CommentCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _ensure_report(report_id, db)
    comment = ReportComment(report_id=report_id, author_id=current_user.id, body=payload.body)
    db.add(comment)
    try:
        await db.commit()
        await db.refresh(comment)
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar el comentario.") from exc
    return CommentResponse(id=comment.id, body=comment.body, created_at=comment.created_at, is_mine=True)


@router.get(
    "/{report_id}/likes",
    response_model=LikesResponse,
    summary="Cuántos se enteraron de un reporte",
    description="Cantidad de \"me enteré\". Con token, `liked` indica si quien consulta ya lo marcó.",
    responses={404: {"description": "El reporte no existe"}},
)
async def get_likes(
    report_id: int,
    current_user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
):
    await _ensure_report(report_id, db)
    try:
        return await _likes(report_id, current_user, db)
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="No se pudo consultar los me enteré.") from exc


@router.put(
    "/{report_id}/likes",
    response_model=LikesResponse,
    summary="Marcar \"me enteré\" en un reporte",
    description="Idempotente: marcarlo dos veces cuenta una sola.",
    responses={401: {"description": "Se requiere iniciar sesión"}, 404: {"description": "El reporte no existe"}},
)
async def like_report(
    report_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _ensure_report(report_id, db)
    try:
        await db.execute(
            insert(ReportLike).values(report_id=report_id, user_id=current_user.id).on_conflict_do_nothing()
        )
        await db.commit()
        return await _likes(report_id, current_user, db)
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo guardar el me enteré.") from exc


@router.delete(
    "/{report_id}/likes",
    response_model=LikesResponse,
    summary="Quitar el \"me enteré\" de un reporte",
    responses={401: {"description": "Se requiere iniciar sesión"}, 404: {"description": "El reporte no existe"}},
)
async def unlike_report(
    report_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _ensure_report(report_id, db)
    try:
        await db.execute(
            delete(ReportLike).where(ReportLike.report_id == report_id, ReportLike.user_id == current_user.id)
        )
        await db.commit()
        return await _likes(report_id, current_user, db)
    except SQLAlchemyError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="No se pudo quitar el me enteré.") from exc
