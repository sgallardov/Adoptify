"""Traduce el formulario "Quiero adoptar" a las preferencias que entiende calculate_match_score."""

from typing import Any

from app.schemas.adoption_profile import AdoptionProfile

# Rangos de edad en meses; un animal de 12 meses ya es adulto
AGE_RANGES = {"cachorro": (0, 11), "adulto": (12, 83), "senior": (84, None)}
# La actividad de quien adopta se compara con la energía del animal (escala 1 a 5)
ENERGY_LEVELS = {"bajo": [1, 2], "medio": [3], "alto": [4, 5]}


def to_preferences(profile: AdoptionProfile) -> dict[str, Any]:
    """Guarda el formulario tal cual y agrega las claves derivadas que usa el motor de match."""
    preferences: dict[str, Any] = {"adoption_profile": profile.model_dump()}
    preferences["preferred_species"] = profile.wanted_species
    preferences["preferred_size"] = profile.wanted_sizes
    if profile.activity_level:
        preferences["preferred_energy_level"] = ENERGY_LEVELS[profile.activity_level]
    # Un solo rango continuo: si se marcan cachorro y senior, también entran los adultos
    if profile.wanted_ages and len(profile.wanted_ages) < len(AGE_RANGES):
        ranges = [AGE_RANGES[age] for age in profile.wanted_ages]
        preferences["min_age_months"] = min(low for low, _ in ranges)
        highs = [high for _, high in ranges]
        preferences["max_age_months"] = None if None in highs else max(highs)
    return preferences
