import pytest
from typing import AsyncGenerator
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.pool import NullPool

from app.main import app
from app.core.config import settings
from app.db.database import get_db

@pytest.fixture(autouse=True)
def local_storage(monkeypatch):
    """Las pruebas nunca suben fotos al bucket compartido de Supabase: usan la carpeta local."""
    monkeypatch.setattr(settings, "SUPABASE_URL", None)
    monkeypatch.setattr(settings, "SUPABASE_SERVICE_KEY", None)
    # Las pruebas siempre usan el Postgres local, así que pueden cifrar el RUT con las claves de
    # desarrollo aunque el .env apunte a la BD compartida (ver core/rut_crypto.py)
    monkeypatch.setattr(settings, "DATABASE_URL", None)


@pytest.fixture
async def test_engine():
    """
    Crea un motor de SQLAlchemy específico para cada prueba usando NullPool.
    Esto previene que las conexiones queden atadas a un event loop cerrado.
    """
    # Siempre la BD local (o TEST_DATABASE_URL): las pruebas crean y borran datos y no deben tocar la compartida
    engine = create_async_engine(
        settings.test_database_url,
        poolclass=NullPool,
        future=True
    )
    yield engine
    await engine.dispose()

@pytest.fixture
async def db_session(test_engine) -> AsyncGenerator[AsyncSession, None]:
    """
    Sesión de base de datos asíncrona aislada por prueba.
    """
    session_factory = async_sessionmaker(
        bind=test_engine,
        class_=AsyncSession,
        expire_on_commit=False
    )
    async with session_factory() as session:
        yield session

@pytest.fixture
async def async_client(test_engine) -> AsyncGenerator[AsyncClient, None]:
    """
    Cliente HTTP asíncrono configurado con la dependencia get_db sobreescrita
    para utilizar el motor de pruebas aislado.
    """
    session_factory = async_sessionmaker(
        bind=test_engine,
        class_=AsyncSession,
        expire_on_commit=False
    )

    async def override_get_db():
        async with session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        yield client

    app.dependency_overrides.clear()
