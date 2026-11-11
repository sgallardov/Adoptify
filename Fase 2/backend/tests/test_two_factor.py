import random
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import decode_access_token, hash_password
from app.models.login_challenge import LoginChallenge
from app.models.user import User
from app.services import email, two_factor

PASSWORD = "ClaveSegura123"


@pytest.fixture(autouse=True)
def outbox(monkeypatch):
    """Las pruebas nunca envían correos: se guardan aquí y el código es siempre el siguiente de la lista."""
    sent: list[dict] = []
    codes = iter(f"{n:06d}" for n in range(111111, 999999, 111111))

    async def fake_send(to, code, purpose, name=None):
        sent.append({"to": to, "code": code, "purpose": purpose})

    monkeypatch.setattr(two_factor, "send_verification_code", fake_send)
    monkeypatch.setattr(two_factor, "generate_code", lambda: next(codes))
    return sent


@pytest.fixture
async def accounts(db_session: AsyncSession):
    """Una cuenta con la verificación en dos pasos activa y otra sin ella; se borran al terminar."""
    tag = uuid.uuid4().hex[:8]

    def user(label: str, enabled: bool) -> User:
        return User(
            email=f"test_2fa_{label}_{tag}@adoptify.cl",
            rut=f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}",
            hashed_password=hash_password(PASSWORD), full_name=f"Test {label}", role="adopter",
            preferences={}, two_factor_enabled=enabled,
        )

    users = {"con": user("con", True), "sin": user("sin", False)}
    db_session.add_all(users.values())
    await db_session.commit()
    yield users

    await db_session.execute(delete(User).where(User.id.in_([u.id for u in users.values()])))
    await db_session.commit()


async def login(client: AsyncClient, user: User):
    return await client.post("/api/v1/auth/login", json={"email": user.email, "password": PASSWORD})


async def headers_for(client: AsyncClient, user: User) -> dict:
    token = (await login(client, user)).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


async def test_sin_verificacion_el_login_entrega_el_token(async_client: AsyncClient, accounts, outbox):
    response = await login(async_client, accounts["sin"])

    assert response.status_code == 200
    assert "access_token" in response.json()
    assert outbox == []


async def test_con_verificacion_envia_codigo_y_no_entrega_token(async_client: AsyncClient, accounts, outbox):
    user = accounts["con"]
    response = await login(async_client, user)

    assert response.status_code == 202
    body = response.json()
    assert "access_token" not in body
    assert body["email_hint"] == f"t***{user.email.split('@')[0][-1]}@adoptify.cl"
    assert body["expires_in_minutes"] == 10
    assert outbox == [{"to": user.email, "code": "111111", "purpose": "login"}]


async def test_contrasena_incorrecta_no_envia_codigo(async_client: AsyncClient, accounts, outbox):
    response = await async_client.post(
        "/api/v1/auth/login", json={"email": accounts["con"].email, "password": "otra-clave-123"}
    )

    assert response.status_code == 401
    assert outbox == []


async def test_codigo_correcto_entrega_el_token(async_client: AsyncClient, accounts, outbox):
    challenge_id = (await login(async_client, accounts["con"])).json()["challenge_id"]

    response = await async_client.post(
        "/api/v1/auth/verify-code", json={"challenge_id": challenge_id, "code": outbox[-1]["code"]}
    )

    assert response.status_code == 200
    assert decode_access_token(response.json()["access_token"]) == accounts["con"].email
    # Un solo uso: el mismo código no sirve dos veces
    again = await async_client.post(
        "/api/v1/auth/verify-code", json={"challenge_id": challenge_id, "code": outbox[-1]["code"]}
    )
    assert again.status_code == 401


async def test_el_codigo_no_se_guarda_en_texto_plano(async_client: AsyncClient, db_session, accounts, outbox):
    challenge_id = (await login(async_client, accounts["con"])).json()["challenge_id"]

    stored = await db_session.get(LoginChallenge, challenge_id)
    assert stored.code_hash != outbox[-1]["code"]
    assert outbox[-1]["code"] not in stored.code_hash
    assert len(stored.code_hash) == 64


async def test_codigo_vencido_obliga_a_iniciar_sesion_otra_vez(async_client: AsyncClient, db_session, accounts, outbox):
    challenge_id = (await login(async_client, accounts["con"])).json()["challenge_id"]
    await db_session.execute(
        update(LoginChallenge)
        .where(LoginChallenge.id == challenge_id)
        .values(expires_at=datetime.now(timezone.utc) - timedelta(seconds=1))
    )
    await db_session.commit()

    response = await async_client.post(
        "/api/v1/auth/verify-code", json={"challenge_id": challenge_id, "code": outbox[-1]["code"]}
    )

    assert response.status_code == 401
    assert response.json()["detail"].startswith("El código venció.")
    assert "access_token" not in response.json()


async def test_cinco_intentos_fallidos_anulan_el_codigo(async_client: AsyncClient, db_session, accounts, outbox):
    challenge_id = (await login(async_client, accounts["con"])).json()["challenge_id"]
    url, wrong = "/api/v1/auth/verify-code", {"challenge_id": challenge_id, "code": "000000"}

    details = [(await async_client.post(url, json=wrong)).json()["detail"] for _ in range(settings.LOGIN_CODE_MAX_ATTEMPTS)]

    assert details[0] == "El código no es correcto. Te quedan 4 intentos."
    assert details[3] == "El código no es correcto. Te queda 1 intento."
    assert details[4].startswith("Demasiados intentos")
    # Ni el código correcto sirve ya: hay que volver a iniciar sesión
    correct = await async_client.post(url, json={"challenge_id": challenge_id, "code": outbox[-1]["code"]})
    assert correct.status_code == 401
    assert (await db_session.execute(select(LoginChallenge).where(LoginChallenge.id == challenge_id))).first() is None


@pytest.mark.parametrize("code", ["12345", "1234567", "abcdef", ""])
async def test_el_codigo_debe_tener_6_digitos(async_client: AsyncClient, code):
    response = await async_client.post("/api/v1/auth/verify-code", json={"challenge_id": str(uuid.uuid4()), "code": code})

    assert response.status_code == 422


async def test_reenviar_espera_un_minuto_y_anula_el_codigo_anterior(
    async_client: AsyncClient, db_session, accounts, outbox
):
    challenge_id = (await login(async_client, accounts["con"])).json()["challenge_id"]
    first_code = outbox[-1]["code"]

    too_soon = await async_client.post("/api/v1/auth/resend-code", json={"challenge_id": challenge_id})
    assert too_soon.status_code == 429

    await db_session.execute(
        update(LoginChallenge)
        .where(LoginChallenge.id == challenge_id)
        .values(last_sent_at=datetime.now(timezone.utc) - timedelta(seconds=61))
    )
    await db_session.commit()
    resent = await async_client.post("/api/v1/auth/resend-code", json={"challenge_id": challenge_id})
    assert resent.status_code == 202
    assert outbox[-1]["code"] != first_code

    old = await async_client.post("/api/v1/auth/verify-code", json={"challenge_id": challenge_id, "code": first_code})
    assert old.status_code == 401
    new = await async_client.post(
        "/api/v1/auth/verify-code", json={"challenge_id": challenge_id, "code": outbox[-1]["code"]}
    )
    assert new.status_code == 200


async def test_activar_exige_confirmar_el_codigo(async_client: AsyncClient, accounts, outbox):
    user = accounts["sin"]
    headers = await headers_for(async_client, user)

    started = await async_client.post("/api/v1/auth/two-factor/enable", headers=headers)
    assert started.status_code == 202
    assert outbox[-1]["purpose"] == "enable"
    # Sin confirmar todavía no está activa
    assert (await async_client.get("/api/v1/auth/me", headers=headers)).json()["two_factor_enabled"] is False

    confirmed = await async_client.post(
        "/api/v1/auth/two-factor/confirm",
        json={"challenge_id": started.json()["challenge_id"], "code": outbox[-1]["code"]},
        headers=headers,
    )
    assert confirmed.status_code == 200
    assert confirmed.json()["two_factor_enabled"] is True
    # El próximo login ya pide código
    assert (await login(async_client, user)).status_code == 202


async def test_el_codigo_de_login_no_sirve_para_activar(async_client: AsyncClient, accounts, outbox):
    headers = await headers_for(async_client, accounts["sin"])
    challenge_id = (await login(async_client, accounts["con"])).json()["challenge_id"]

    response = await async_client.post(
        "/api/v1/auth/two-factor/confirm",
        json={"challenge_id": challenge_id, "code": outbox[-1]["code"]},
        headers=headers,
    )

    # 400 y no 401: con la sesión iniciada, un 401 haría que la app cierre la sesión
    assert response.status_code == 400


async def test_desactivar_pide_la_contrasena(async_client: AsyncClient, accounts, outbox):
    user = accounts["con"]
    challenge_id = (await login(async_client, user)).json()["challenge_id"]
    token = (
        await async_client.post("/api/v1/auth/verify-code", json={"challenge_id": challenge_id, "code": outbox[-1]["code"]})
    ).json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    wrong = await async_client.post("/api/v1/auth/two-factor/disable", json={"password": "otra-clave-123"}, headers=headers)
    assert wrong.status_code == 400

    ok = await async_client.post("/api/v1/auth/two-factor/disable", json={"password": PASSWORD}, headers=headers)
    assert ok.json()["two_factor_enabled"] is False
    assert (await login(async_client, user)).status_code == 200


async def test_sin_proveedor_fuera_de_development_no_entrega_codigo(async_client: AsyncClient, accounts, monkeypatch):
    monkeypatch.setattr(two_factor, "send_verification_code", email.send_verification_code)
    monkeypatch.setattr(settings, "SMTP_HOST", None)
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")

    response = await login(async_client, accounts["con"])

    assert response.status_code == 503
    assert "access_token" not in response.json()


async def test_en_development_sin_proveedor_el_codigo_va_a_los_logs(
    async_client: AsyncClient, accounts, monkeypatch, caplog
):
    monkeypatch.setattr(two_factor, "send_verification_code", email.send_verification_code)
    monkeypatch.setattr(settings, "SMTP_HOST", None)
    monkeypatch.setattr(settings, "ENVIRONMENT", "development")

    response = await login(async_client, accounts["con"])

    assert response.status_code == 202
    assert "Correo sin enviar" in caplog.text
