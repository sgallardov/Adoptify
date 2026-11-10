from fastapi import APIRouter
from app.api.v1.endpoints import health, auth, animals, foundations, reports, uploads, users, veterinary_clinics, foundation_members

api_router = APIRouter()

# Registro de rutas de la versión 1 de la API
api_router.include_router(health.router, tags=["Health"])
api_router.include_router(auth.router, prefix="/auth", tags=["Autenticación"])
api_router.include_router(users.router, prefix="/users", tags=["Usuarios"])
api_router.include_router(animals.router, prefix="/animals", tags=["Animales"])
api_router.include_router(foundations.router, prefix="/foundations", tags=["Fundaciones"])
api_router.include_router(foundation_members.router, prefix="/foundations", tags=["Socios de la fundación"])
api_router.include_router(reports.router, prefix="/reports", tags=["Reportes de perros abandonados"])
api_router.include_router(uploads.router, prefix="/uploads", tags=["Imágenes"])
api_router.include_router(veterinary_clinics.router, prefix="/veterinary-clinics", tags=["Clínicas veterinarias"])
api_router.include_router(veterinary_clinics.router, prefix="/veterinaries", tags=["Veterinarias"])
