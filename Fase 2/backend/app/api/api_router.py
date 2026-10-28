from fastapi import APIRouter
from app.api.v1.endpoints import health, auth, animals, reports

api_router = APIRouter()

# Registro de rutas de la versión 1 de la API
api_router.include_router(health.router, tags=["Health"])
api_router.include_router(auth.router, prefix="/auth", tags=["Autenticación"])
api_router.include_router(animals.router, prefix="/animals", tags=["Animales"])
api_router.include_router(reports.router, prefix="/reports", tags=["Reportes de perros abandonados"])
