from fastapi import APIRouter, Depends, HTTPException, Query, status
from geoalchemy2 import Geography
from geoalchemy2.elements import WKTElement
from sqlalchemy import cast, func, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.auth import get_current_user
from app.db.database import get_db
from app.models.report import AbandonedDogReport
from app.models.user import User
from app.schemas.report import NearbyReportResponse, ReportCreate, ReportResponse

router = APIRouter()


@router.post(
    "",
    response_model=ReportResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Reportar un perro abandonado",
    responses={401: {"description": "Se requiere iniciar sesión"}},
)
async def create_report(
    payload: ReportCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    report = AbandonedDogReport(
        reporter_id=current_user.id,
        description=payload.description.strip(),
        photo_url=payload.photo_url,
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
        "Devuelve los reportes de perros abandonados que aún no están resueltos dentro del radio indicado, "
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
