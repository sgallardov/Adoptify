"""Formulario "Quiero adoptar": traducción a preferencias del match y endpoints del perfil."""

import random
import uuid

from httpx import AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.animal import Animal
from app.models.user import User
from app.schemas.adoption_profile import AdoptionProfile
from app.services.adoption_profile import to_preferences
from app.services.match import calculate_match_score

FORM = {
    "housing_type": "departamento",
    "has_kids": "no",
    "has_pets": "si",
    "hours_alone": "2_5",
    "activity_level": "medio",
    "experience": "algo",
    "wanted_species": ["perro", "gato"],
    "wanted_sizes": ["pequeño", "mediano"],
    "wanted_ages": ["adulto"],
    "accepts_follow_up": True,
}


def test_form_becomes_match_preferences():
    preferences = to_preferences(AdoptionProfile(**FORM))
    assert preferences["preferred_species"] == ["perro", "gato"]
    assert preferences["preferred_size"] == ["pequeño", "mediano"]
    assert preferences["preferred_energy_level"] == [3]
    assert (preferences["min_age_months"], preferences["max_age_months"]) == (12, 83)
    assert preferences["adoption_profile"]["housing_type"] == "departamento"


def test_any_age_and_no_activity_are_left_out_of_the_match():
    preferences = to_preferences(AdoptionProfile(**{**FORM, "wanted_ages": [], "activity_level": None}))
    assert "min_age_months" not in preferences
    assert "preferred_energy_level" not in preferences


def test_senior_has_no_upper_age_limit():
    preferences = to_preferences(AdoptionProfile(**{**FORM, "wanted_ages": ["senior"]}))
    assert (preferences["min_age_months"], preferences["max_age_months"]) == (84, None)


def test_match_accepts_lists_of_preferences():
    animal = Animal(name="Luna", species="gato", size="mediano", age_months=24, energy_level=3)
    assert calculate_match_score(to_preferences(AdoptionProfile(**FORM)), animal) == 100.0
    other = Animal(name="Rex", species="perro", size="grande", age_months=24, energy_level=5)
    assert calculate_match_score(to_preferences(AdoptionProfile(**FORM)), other) == 30 + 25


@pytest.fixture
async def adopter_headers(async_client: AsyncClient, db_session: AsyncSession):
    email = f"perfil_{uuid.uuid4().hex[:10]}@adoptify.cl"
    rut = f"{random.randint(30_000_000, 99_999_999)}-{random.choice('0123456789K')}"
    await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "rut": rut, "password": "ClaveSegura123", "full_name": "Usuario Perfil"},
    )
    login = await async_client.post("/api/v1/auth/login", json={"email": email, "password": "ClaveSegura123"})
    yield {"Authorization": f"Bearer {login.json()['access_token']}"}
    await db_session.execute(delete(User).where(User.email == email))
    await db_session.commit()


async def test_profile_requires_login(async_client: AsyncClient):
    assert (await async_client.get("/api/v1/users/me/adoption-profile")).status_code in (401, 403)


async def test_profile_is_null_until_completed(async_client: AsyncClient, adopter_headers):
    response = await async_client.get("/api/v1/users/me/adoption-profile", headers=adopter_headers)
    assert response.status_code == 200
    assert response.json() is None


async def test_save_and_edit_profile(async_client: AsyncClient, adopter_headers):
    saved = await async_client.put("/api/v1/users/me/adoption-profile", json=FORM, headers=adopter_headers)
    assert saved.status_code == 200
    assert (await async_client.get("/api/v1/users/me/adoption-profile", headers=adopter_headers)).json() == FORM

    edited = {**FORM, "housing_type": "casa_patio", "wanted_species": ["perro"]}
    await async_client.put("/api/v1/users/me/adoption-profile", json=edited, headers=adopter_headers)
    assert (await async_client.get("/api/v1/users/me/adoption-profile", headers=adopter_headers)).json() == edited


async def test_missing_required_fields_are_rejected(async_client: AsyncClient, adopter_headers):
    invalid = {k: v for k, v in FORM.items() if k not in ("housing_type", "wanted_species")}
    response = await async_client.put("/api/v1/users/me/adoption-profile", json=invalid, headers=adopter_headers)
    assert response.status_code == 422
