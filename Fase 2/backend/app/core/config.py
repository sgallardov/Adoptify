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

    # RUT cifrado (HU-E). RUT_ENCRYPTION_KEY es una clave Fernet (cifra y descifra el RUT);
    # RUT_HASH_KEY firma el hash con el que se busca y se evita repetir un RUT.
    # Los valores por defecto solo sirven en el Postgres local: con DATABASE_URL (BD compartida)
    # el backend se niega a usarlos (ver core/rut_crypto.py). Si se pierden las claves reales,
    # los RUT guardados no se pueden recuperar: respaldarlas fuera del repositorio.
    RUT_ENCRYPTION_KEY: str = "YWRvcHRpZnktZGV2LXNvbG8tbG9jYWwtcnV0LWtleSE="
    RUT_HASH_KEY: str = "adoptify-dev-solo-local-rut-hash"

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
    # Vigencia de cada enlace firmado de foto. Más largo = más reutilización (CDN y caché del teléfono);
    # más corto = un enlace copiado deja de servir antes.
    PHOTO_LINK_HOURS: int = 6

    # Correo saliente (HU-I, código de verificación). SMTP estándar: con Gmail, smtp.gmail.com:587, la cuenta
    # en SMTP_USER y una "contraseña de aplicación" en SMTP_PASSWORD. Solo en el .env, nunca en el repo.
    # Sin SMTP_HOST, en development el correo se escribe en los logs del backend en vez de enviarse.
    SMTP_HOST: Optional[str] = None
    SMTP_PORT: int = 587
    SMTP_USER: Optional[str] = None
    SMTP_PASSWORD: Optional[str] = None
    EMAIL_FROM: Optional[str] = None  # Remitente; si falta, se usa SMTP_USER
    EMAIL_FROM_NAME: str = "Adoptify"

    # Verificación en dos pasos por correo
    LOGIN_CODE_MINUTES: int = 10
    LOGIN_CODE_MAX_ATTEMPTS: int = 5
    LOGIN_CODE_RESEND_SECONDS: int = 60

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
    def email_enabled(self) -> bool:
        """Se envían correos de verdad solo si está el servidor SMTP con su cuenta y contraseña."""
        return bool(self.SMTP_HOST and self.SMTP_USER and self.SMTP_PASSWORD)

    @property
    def uses_shared_db(self) -> bool:
        """La BD está lejos (Supabase): cada ida y vuelta cuesta ~130 ms desde Chile."""
        return bool(self.DATABASE_URL)

    @property
    def db_pool_options(self) -> dict:
        """
        Opciones del pool de conexiones. Con la BD compartida:
        - sin pool_pre_ping: verificar la conexión antes de cada petición costaba una ida y vuelta extra;
        - pool_use_lifo: se reutiliza siempre la última conexión usada, que se mantiene viva
          (ver keep_connections_warm en database.py) en vez de rotar entre varias que se enfrían;
        - pool chico: el pooler de Supabase limita las conexiones y somos varios backends.
        En local la verificación no cuesta nada y se mantiene.
        """
        if self.uses_shared_db:
            return {"pool_pre_ping": False, "pool_use_lifo": True, "pool_recycle": 1800,
                    "pool_size": 3, "max_overflow": 2}
        return {"pool_pre_ping": True}

    @property
    def db_connect_args(self) -> dict:
        """Opciones de asyncpg para la conexión principal (SSL en Supabase)."""
        return {"ssl": "require"} if self.DB_SSL else {}

settings = Settings()
