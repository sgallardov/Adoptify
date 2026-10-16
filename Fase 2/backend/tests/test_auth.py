import pytest
from httpx import AsyncClient
from app.schemas.auth import RUTValidateResponse

class TestAuthRUTHU03:
    """
    Pruebas automatizadas para los Criterios de Aceptación de HU-03 (Autenticación / Validación RUT).
    Verifica validación de sintaxis de RUT chileno con Regex y la regla Mock de dígito par (200) e impar (400).
    """

    async def test_validate_rut_even_digit_with_dots_returns_200(self, async_client: AsyncClient):
        """
        Criterio: RUT chileno válido que termina en número par (ej: 4) retorna HTTP 200 y is_valid: True.
        """
        payload = {"rut": "76.452.189-4"}
        response = await async_client.post("/api/v1/auth/validate-rut", json=payload)
        
        assert response.status_code == 200
        data = response.json()
        validated = RUTValidateResponse(**data)
        assert validated.is_valid is True
        assert validated.rut == "76.452.189-4"
        assert "dígito par" in validated.message

    async def test_validate_rut_even_digit_without_dots_returns_200(self, async_client: AsyncClient):
        """
        Criterio: RUT chileno sin puntos que termina en número par (ej: 2) retorna HTTP 200.
        """
        payload = {"rut": "12345678-2"}
        response = await async_client.post("/api/v1/auth/validate-rut", json=payload)
        
        assert response.status_code == 200
        data = response.json()
        assert data["is_valid"] is True
        assert data["rut"] == "12345678-2"

    async def test_validate_rut_even_zero_returns_200(self, async_client: AsyncClient):
        """
        Criterio: RUT chileno que termina en 0 (par) retorna HTTP 200.
        """
        payload = {"rut": "11.222.333-0"}
        response = await async_client.post("/api/v1/auth/validate-rut", json=payload)
        
        assert response.status_code == 200
        data = response.json()
        assert data["is_valid"] is True

    async def test_validate_rut_odd_digit_returns_400(self, async_client: AsyncClient):
        """
        Criterio: RUT chileno válido que termina en número impar (ej: 3) retorna HTTP 400.
        """
        payload = {"rut": "76.452.189-3"}
        response = await async_client.post("/api/v1/auth/validate-rut", json=payload)
        
        assert response.status_code == 400
        data = response.json()
        assert "detail" in data
        assert data["detail"]["is_valid"] is False
        assert data["detail"]["rut"] == "76.452.189-3"
        assert "impar" in data["detail"]["message"].lower()

    async def test_validate_rut_letter_k_returns_400(self, async_client: AsyncClient):
        """
        Criterio: RUT chileno que termina en letra 'K' (no par) retorna HTTP 400.
        """
        payload = {"rut": "77.102.348-K"}
        response = await async_client.post("/api/v1/auth/validate-rut", json=payload)
        
        assert response.status_code == 400
        data = response.json()
        assert data["detail"]["is_valid"] is False
        assert "K" in data["detail"]["rut"]

    async def test_validate_rut_invalid_syntax_returns_422(self, async_client: AsyncClient):
        """
        Criterio de Aceptación: Endpoint valida la sintaxis del RUT chileno mediante Regex.
        Cualquier cadena con formato no chileno debe ser rechazada con HTTP 422.
        """
        invalid_ruts = ["texto_cualquiera", "12345", "12.34.56", "12.345.678", "76452189"]
        for bad_rut in invalid_ruts:
            response = await async_client.post("/api/v1/auth/validate-rut", json={"rut": bad_rut})
            assert response.status_code == 422, f"Falló para el RUT inválido: {bad_rut}"
            data = response.json()
            assert "detail" in data
