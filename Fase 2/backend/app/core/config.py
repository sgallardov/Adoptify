from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional

class Settings(BaseSettings):
    PROJECT_NAME: str = "Adoptify API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"

    # Configuración de PostgreSQL y PostGIS
    DB_USER: str = "adoptify_user"
    DB_PASS: str = "adoptify_password123"
    DB_NAME: str = "adoptify_db"
    DB_HOST: str = "db"
    DB_PORT: int = 5432
    # BD compartida (Supabase): si está, reemplaza a DB_*. Ver "Base de datos compartida" en el README.
    DATABASE_URL: Optional[str] = None
    # Supabase exige conexión cifrada; el Postgres local de Docker no
    DB_SSL: bool = False
    # Las pruebas escriben datos: por defecto usan el Postgres local (DB_*), nunca la BD compartida
    TEST_DATABASE_URL: Optional[str] = None

    # Autenticación JWT
    SECRET_KEY: str = "cambiar-esta-clave-en-produccion"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # Fotos subidas (HU-16): carpeta local servida en /uploads y tamaño máximo por archivo
    UPLOAD_DIR: str = "uploads"
    MAX_UPLOAD_MB: int = 5
    # URL pública del backend para armar el enlace de cada foto; si está vacía se usa la del request
    PUBLIC_BASE_URL: Optional[str] = None
    # Fotos compartidas en Supabase Storage (bucket público). Sin estas dos, se guardan en UPLOAD_DIR.
    # La llave secreta solo va en el .env del backend: nunca en la app ni en el portal.
    SUPABASE_URL: Optional[str] = None
    SUPABASE_SERVICE_KEY: Optional[str] = None
    SUPABASE_BUCKET: str = "fotos"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    @property
    def async_database_url(self) -> str:
        """
        Retorna la URL de conexión asíncrona compatible con asyncpg y SQLAlchemy 2.0.
        """
        if self.DATABASE_URL:
            # Asegurar prefijo de driver asyncpg si viene como postgresql://
            if self.DATABASE_URL.startswith("postgresql://"):
                return self.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)
            return self.DATABASE_URL
        return self.local_database_url

    @property
    def local_database_url(self) -> str:
        """El Postgres + PostGIS del docker compose (servicio db)."""
        return f"postgresql+asyncpg://{self.DB_USER}:{self.DB_PASS}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"

    @property
    def test_database_url(self) -> str:
        """BD de las pruebas: TEST_DATABASE_URL o, si no está, la local."""
        return self.TEST_DATABASE_URL or self.local_database_url

    @property
    def storage_enabled(self) -> bool:
        """Las fotos van a Supabase Storage solo si están la URL del proyecto y la llave secreta."""
        return bool(self.SUPABASE_URL and self.SUPABASE_SERVICE_KEY)

    @property
    def db_connect_args(self) -> dict:
        """Opciones de asyncpg para la conexión principal (SSL en Supabase)."""
        return {"ssl": "require"} if self.DB_SSL else {}

settings = Settings()
