import pytest
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings

class TestInfraHU01:
    """
    Pruebas automatizadas para los Criterios de Aceptación de HU-01 (Infraestructura).
    Verifica configuración, variables de entorno, conexión local y extensión PostGIS.
    """

    def test_environment_variables_loaded(self):
        """Verifica que las variables de entorno (.env) se carguen correctamente."""
        assert settings.DB_USER is not None
        assert settings.DB_NAME is not None
        assert settings.DB_PORT == 5432
        assert "asyncpg" in settings.async_database_url

    async def test_database_connection_and_postgis(self, db_session: AsyncSession):
        """
        Criterio: Contenedor de BD acepta conexiones locales y tiene PostGIS habilitado.
        """
        # 1. Conexión básica
        result = await db_session.execute(text("SELECT 1"))
        assert result.scalar() == 1

        # 2. Extensión PostGIS instalada y operativa
        pg_version = await db_session.execute(text("SELECT PostGIS_Version()"))
        version_str = pg_version.scalar()
        assert version_str is not None
        assert "3." in version_str or "POSTGIS" in version_str.upper()

    async def test_database_persistence_operations(self, db_session: AsyncSession):
        """
        Criterio: Persistencia y operaciones DDL/DML operativas en el contenedor de BD.
        """
        try:
            await db_session.execute(text("CREATE TABLE IF NOT EXISTS test_infra_persist (id serial PRIMARY KEY, val text);"))
            await db_session.execute(text("INSERT INTO test_infra_persist (val) VALUES ('adoptify_infra_ok');"))
            await db_session.commit()

            res = await db_session.execute(text("SELECT val FROM test_infra_persist WHERE val = 'adoptify_infra_ok';"))
            assert res.scalar() == "adoptify_infra_ok"
        finally:
            await db_session.execute(text("DROP TABLE IF EXISTS test_infra_persist;"))
            await db_session.commit()


class TestSharedDatabaseConfig:
    """BD compartida (Supabase): SSL opcional y pruebas siempre fuera de la BD compartida."""

    def test_supabase_url_uses_asyncpg_and_ssl(self):
        from app.core.config import Settings

        shared = Settings(
            _env_file=None,
            DATABASE_URL="postgresql://postgres.abc:clave@aws-0-sa-east-1.pooler.supabase.com:5432/postgres",
            DB_SSL=True,
        )
        assert shared.async_database_url.startswith("postgresql+asyncpg://")
        assert shared.db_connect_args == {"ssl": "require"}

    def test_tests_never_use_the_shared_database(self):
        from app.core.config import Settings

        shared = Settings(_env_file=None, DATABASE_URL="postgresql://u:p@remoto.supabase.com:5432/postgres", DB_HOST="db")
        assert "supabase" not in shared.test_database_url
        assert "@db:5432/" in shared.test_database_url
        # Sin DB_SSL, la conexión local de Docker va sin cifrar (el .env de cada uno puede activarlo)
        assert Settings.model_fields["DB_SSL"].default is False
        assert Settings(_env_file=None, DB_SSL=False).db_connect_args == {}
