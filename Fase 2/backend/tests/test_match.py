"""HU-05: pruebas del motor de match sin conexión a PostgreSQL."""

import pytest

from app.models.animal import Animal
from app.services.match import calculate_match_score


@pytest.fixture
def animal():
    return Animal(
        name="Rocky",
        species="perro",
        size="mediano",
        age_months=18,
        energy_level=4,
    )


def test_total_compatibility(animal):
    preferences = {
        "preferred_species": " Perro ",
        "preferred_size": "mediano",
        "min_age_months": 18,
        "max_age_months": 36,
        "preferred_energy_level": 4,
    }
    score = calculate_match_score(preferences, animal)
    assert isinstance(score, float)
    assert score == 100.0


def test_partial_compatibility(animal):
    # Coinciden especie (30) y edad (25); tamaño y energía difieren.
    preferences = {
        "preferred_species": "perro",
        "preferred_size": "pequeño",
        "min_age_months": 6,
        "max_age_months": 18,
        "preferred_energy_level": 2,
    }
    assert calculate_match_score(preferences, animal) == 55.0


def test_no_compatibility(animal):
    preferences = {
        "preferred_species": "gato",
        "preferred_size": "pequeño",
        "min_age_months": 1,
        "max_age_months": 12,
        "preferred_energy_level": 1,
    }
    assert calculate_match_score(preferences, animal) == 0.0


@pytest.mark.parametrize(
    "preferences, expected",
    [
        ({}, 0.0),
        ({"preferred_species": None}, 0.0),
        ({"housing_type": "departamento"}, 0.0),
        ({"preferred_species": "perro"}, 100.0),
        ({"preferred_species": "perro", "preferred_size": "pequeño"}, 54.55),
        ({"min_age_months": 18}, 100.0),
        ({"max_age_months": 17}, 0.0),
    ],
)
def test_optional_preferences(animal, preferences, expected):
    assert calculate_match_score(preferences, animal) == expected


def test_unknown_age_is_omitted(animal):
    animal.age_months = None
    preferences = {"preferred_species": "perro", "max_age_months": 12}
    assert calculate_match_score(preferences, animal) == 100.0


def test_inverted_age_range_is_rejected(animal):
    with pytest.raises(ValueError, match="min_age_months"):
        calculate_match_score({"min_age_months": 24, "max_age_months": 12}, animal)
