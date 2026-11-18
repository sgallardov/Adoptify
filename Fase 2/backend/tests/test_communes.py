import pytest
from pydantic import ValidationError

from app.schemas.animal import CommuneInput
from app.services.commune_renames import COMMUNE_RENAMES
from app.services.communes import COMMUNES, find_commune


def test_catalog_uses_the_corrected_names():
    assert len(COMMUNES) == 346
    for old, new in COMMUNE_RENAMES.items():
        assert new in COMMUNES, new
        assert old not in COMMUNES, old


def test_find_commune_ignores_accents_case_and_apostrophes():
    assert find_commune("aysen") == "Aysén"
    assert find_commune("  ÑUÑOA ") == "Ñuñoa"
    assert find_commune("Nunoa") == "Ñuñoa"
    assert find_commune("O Higgins") == "O'Higgins"
    assert find_commune("Dirección particular") is None
    assert find_commune(None) is None


def test_old_commune_name_is_rejected():
    # El esquema solo acepta nombres del catálogo corregido
    with pytest.raises(ValidationError):
        CommuneInput(public_commune="Aisen")
    assert CommuneInput(public_commune="Aysén").public_commune == "Aysén"
