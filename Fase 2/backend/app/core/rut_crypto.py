"""
RUT cifrado (HU-E).

La BD no guarda el RUT en texto plano. Cada usuario tiene dos columnas:
- rut_encrypted: el RUT normalizado cifrado con Fernet (RUT_ENCRYPTION_KEY). Se descifra para /me.
- rut_hash: HMAC-SHA256 del RUT normalizado (RUT_HASH_KEY). Es determinista, así que sirve para
  buscar por RUT y para el índice único que impide registrar el mismo RUT dos veces.
"""
import hashlib
import hmac

from cryptography.fernet import Fernet, InvalidToken

from app.core.config import Settings, settings
from app.core.rut import normalize_rut

_DEFAULTS = Settings.model_fields


def _check_keys() -> None:
    """Con la BD compartida no se aceptan las claves de desarrollo que vienen en el código."""
    using_shared_db = bool(settings.DATABASE_URL)
    default_key = settings.RUT_ENCRYPTION_KEY == _DEFAULTS["RUT_ENCRYPTION_KEY"].default
    default_hash = settings.RUT_HASH_KEY == _DEFAULTS["RUT_HASH_KEY"].default
    if using_shared_db and (default_key or default_hash):
        raise RuntimeError(
            "Faltan RUT_ENCRYPTION_KEY y RUT_HASH_KEY propias en el .env: con la BD compartida "
            "no se pueden usar las claves de desarrollo. Ver 'RUT cifrado' en el README."
        )


def _fernet() -> Fernet:
    _check_keys()
    return Fernet(settings.RUT_ENCRYPTION_KEY.encode())


def hash_rut(rut: str) -> str:
    """Hash determinista del RUT normalizado: 12.345.678-5 y 12345678-5 dan el mismo valor."""
    _check_keys()
    normalized = normalize_rut(rut)
    return hmac.new(settings.RUT_HASH_KEY.encode(), normalized.encode(), hashlib.sha256).hexdigest()


def encrypt_rut(rut: str) -> str:
    return _fernet().encrypt(normalize_rut(rut).encode()).decode()


def decrypt_rut(token: str) -> str:
    try:
        return _fernet().decrypt(token.encode()).decode()
    except InvalidToken as error:
        # Clave distinta a la que cifró el dato: no se adivina nada, se avisa
        raise RuntimeError("No se pudo descifrar un RUT: RUT_ENCRYPTION_KEY no coincide con la usada al guardarlo") from error
