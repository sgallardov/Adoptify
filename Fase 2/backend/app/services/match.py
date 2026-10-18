"""Cálculo local de compatibilidad entre preferencias y un animal."""

from typing import Any, Mapping

from app.models.animal import Animal


def calculate_match_score(preferences: Mapping[str, Any], animal: Animal) -> float:
    """Retorna un porcentaje de 0.0 a 100.0 sin consultar la base de datos.

    Criterios: preferred_species (30), preferred_size (25), rango inclusivo
    min_age_months/max_age_months (25) y preferred_energy_level (20).
    Cada coincidencia aporta el peso completo; las diferencias aportan cero.
    Los textos se comparan sin distinguir mayúsculas ni espacios exteriores.
    Se omiten preferencias o atributos ausentes (None), recalculando el total
    sobre los pesos disponibles. Sin criterios comparables se retorna 0.0.
    Las claves adicionales, como housing_type, no afectan el resultado.
    """
    earned = 0.0
    available = 0.0

    for key, attribute, weight in (
        ("preferred_species", "species", 30.0),
        ("preferred_size", "size", 25.0),
        ("preferred_energy_level", "energy_level", 20.0),
    ):
        preferred = preferences.get(key)
        actual = getattr(animal, attribute)
        if preferred is None or actual is None:
            continue
        if isinstance(preferred, str) and isinstance(actual, str):
            preferred = preferred.strip().casefold()
            actual = actual.strip().casefold()
        available += weight
        if preferred == actual:
            earned += weight

    minimum = preferences.get("min_age_months")
    maximum = preferences.get("max_age_months")
    if minimum is not None and maximum is not None and minimum > maximum:
        raise ValueError("min_age_months no puede ser mayor que max_age_months")
    if animal.age_months is not None and (minimum is not None or maximum is not None):
        available += 25.0
        if (minimum is None or animal.age_months >= minimum) and (
            maximum is None or animal.age_months <= maximum
        ):
            earned += 25.0

    return round(earned / available * 100.0, 2) if available else 0.0
