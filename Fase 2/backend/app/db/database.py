from typing import AsyncGenerator, Dict, Any
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import text
from app.core.config import settings

# Creación del motor asíncrono con SQLAlchemy 2.0 y asyncpg
engine = create_async_engine(
    settings.async_database_url,
    echo=False,
    future=True,
    pool_pre_ping=True
)

# Fábrica de sesiones asíncronas
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False
)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependencia FastAPI que provee una sesión de base de datos asíncrona por petición.
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

async def check_database_connection(session: AsyncSession) -> Dict[str, Any]:
    """
    Verifica la conectividad activa con PostgreSQL y el soporte de la extensión PostGIS.
    """
    # 1. Comprobación básica de conectividad
    result = await session.execute(text("SELECT 1"))
    connected = result.scalar() == 1

    # 2. Comprobación de PostGIS
    postgis_version = "No detectado"
    try:
        pg_res = await session.execute(text("SELECT PostGIS_Version()"))
        postgis_version = pg_res.scalar() or "Habilitado"
    except Exception:
        # Si la extensión no estuviese habilitada en la BD actual
        postgis_version = "Extensión no inicializada"

    return {
        "connected": connected,
        "postgis_version": postgis_version
    }
