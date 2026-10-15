from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging

from app.core.config import settings
from app.api.api_router import api_router
from app.api.v1.endpoints.health import router as health_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("adoptify")

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Gestor de ciclo de vida de la aplicación.
    Ejecuta verificaciones al iniciar y limpieza al apagar el servidor.
    """
    logger.info("Iniciando Adoptify API...")
    logger.info(f"Conectando a base de datos en: {settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}")
    yield
    logger.info("Apagando Adoptify API...")

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Backend API para la plataforma de adopción y rescate animal Adoptify (FastAPI + PostgreSQL/PostGIS)",
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Configuración de CORS para permitir solicitudes de Frontend Web y App Móvil
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Endpoint raíz informativo
@app.get("/", tags=["General"])
async def root():
    return {
        "status": "online",
        "app": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT,
        "documentation": "/docs",
        "health": "/health"
    }

# Endpoint /health directo en la raíz (criterio de aceptación HU-02)
app.include_router(health_router, tags=["Health"])

# Router principal con prefijo /api/v1
app.include_router(api_router, prefix=settings.API_V1_STR)
