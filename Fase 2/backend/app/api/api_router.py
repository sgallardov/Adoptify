from fastapi import APIRouter
from app.api.v1.endpoints import health, auth

api_router = APIRouter()

# Registro de rutas de la versión 1 de la API
api_router.include_router(health.router, tags=["Health"])
api_router.include_router(auth.router, prefix="/auth", tags=["Autenticación"])
