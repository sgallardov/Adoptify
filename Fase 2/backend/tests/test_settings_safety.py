import pytest
from pydantic import ValidationError

from app.core.config import Settings

REAL = {"SECRET_KEY": "x" * 40, "RUT_ENCRYPTION_KEY": "k" * 44, "RUT_HASH_KEY": "h" * 32}


def test_development_accepts_example_keys():
    Settings(_env_file=None, ENVIRONMENT="development")


def test_production_refuses_example_keys():
    with pytest.raises(ValidationError, match="SECRET_KEY"):
        Settings(_env_file=None, ENVIRONMENT="production")


def test_production_accepts_real_keys():
    Settings(_env_file=None, ENVIRONMENT="production", **REAL)


def test_cors_origins_are_a_clean_list():
    settings = Settings(_env_file=None, CORS_ORIGINS="http://a.cl/, http://b.cl")
    assert settings.cors_origins == ["http://a.cl", "http://b.cl"]
