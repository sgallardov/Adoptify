from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.database import get_db, check_database_connection
from app.schemas.health import HealthResponse, DatabaseStatus
from app.core.config import settings

router = APIRouter()

@router.get(
    "/health",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Verificar estado del backend y conexión a base de datos",
    description="Comprueba la disponibilidad del servicio FastAPI y ejecuta una consulta asíncrona hacia PostgreSQL/PostGIS."
)
async def check_health(db: AsyncSession = Depends(get_db)):
    try:
        db_check = await check_database_connection(db)
        return HealthResponse(
            status="ok",
            service=settings.PROJECT_NAME,
            environment=settings.ENVIRONMENT,
            database=DatabaseStatus(
                connected=db_check["connected"],
                postgis_version=db_check["postgis_version"]
            )
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "status": "error",
                "service": settings.PROJECT_NAME,
                "environment": settings.ENVIRONMENT,
                "database": {
                    "connected": False,
                    "error": str(e)
                }
            }
        )
