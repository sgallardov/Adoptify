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
    DATABASE_URL: Optional[str] = None

    # Autenticación JWT
    SECRET_KEY: str = "cambiar-esta-clave-en-produccion"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

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
        return f"postgresql+asyncpg://{self.DB_USER}:{self.DB_PASS}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"

settings = Settings()
