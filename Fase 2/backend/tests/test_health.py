import pytest
from httpx import AsyncClient
from app.schemas.health import HealthResponse

class TestBackendCoreHU02:
    """
    Pruebas automatizadas para los Criterios de Aceptación de HU-02 (Backend Core).
    Verifica endpoints HTTP, Swagger UI y validación de esquemas Pydantic v2.
    """

    async def test_root_endpoint_returns_online(self, async_client: AsyncClient):
        """Verifica que el endpoint raíz responda HTTP 200 con información del servicio."""
        response = await async_client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "online"
        assert "Adoptify" in data["app"]

    async def test_swagger_ui_accessible(self, async_client: AsyncClient):
        """
        Criterio: Swagger UI autogenerado accesible en /docs.
        """
        response = await async_client.get("/docs")
        assert response.status_code == 200
        assert "swagger-ui" in response.text.lower() or "html" in response.headers.get("content-type", "").lower()

    async def test_openapi_schema_generated(self, async_client: AsyncClient):
        """Verifica que el esquema OpenAPI v3 JSON sea válido y accesible."""
        response = await async_client.get("/api/v1/openapi.json")
        assert response.status_code == 200
        data = response.json()
        assert "openapi" in data
        assert data["info"]["title"] == "Adoptify API"

    async def test_health_endpoint_returns_200_and_db_status(self, async_client: AsyncClient):
        """
        Criterio: Endpoint /health retorna HTTP 200 y status de BD.
        """
        response = await async_client.get("/health")
        assert response.status_code == 200
        data = response.json()

        # Validación estructural y tipada con Pydantic v2
        health_schema = HealthResponse(**data)
        assert health_schema.status == "ok"
        assert health_schema.database.connected is True
        assert health_schema.database.postgis_version is not None
        assert "3." in health_schema.database.postgis_version or "USE_GEOS" in health_schema.database.postgis_version

    async def test_api_v1_health_endpoint(self, async_client: AsyncClient):
        """Verifica el endpoint de salud bajo el enrutador /api/v1/health."""
        response = await async_client.get("/api/v1/health")
        assert response.status_code == 200
        data = response.json()
        assert data["database"]["connected"] is True
