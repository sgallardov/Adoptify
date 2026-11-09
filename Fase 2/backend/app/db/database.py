import asyncio
import logging
from typing import AsyncGenerator, Dict, Any
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import text
from app.core.config import settings

# Creación del motor asíncrono con SQLAlchemy 2.0 y asyncpg
engine = create_async_engine(
    settings.async_database_url,
    echo=False,
    future=True,
    connect_args=settings.db_connect_args,
    **settings.db_pool_options,
)

# Con la BD compartida, abrir una conexión nueva cuesta ~3 s (SSL + pooler, desde Chile). Se abre una al
# arrancar y se usa cada pocos minutos para que nunca la pague una petición de la app.
KEEP_WARM_SECONDS = 180


async def warm_up() -> None:
    """Abre (o reutiliza) una conexión del pool con una consulta mínima."""
    async with engine.connect() as connection:
        await connection.execute(text("SELECT 1"))


async def keep_connections_warm() -> None:
    """Tarea de fondo: mantiene viva la conexión y, cuando toca renovarla (pool_recycle), lo hace aquí."""
    while True:
        try:
            await warm_up()
        except Exception as exc:  # sin BD la app sigue respondiendo con sus 503; se reintenta en la próxima vuelta
            logging.getLogger("adoptify").warning("No se pudo mantener la conexión a la BD: %s", exc)
        await asyncio.sleep(KEEP_WARM_SECONDS)

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
