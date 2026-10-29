import argparse
import asyncio
import logging
from sqlalchemy import select

from app.core.rut import normalize_rut
from app.core.security import hash_password
from app.db.database import AsyncSessionLocal
from app.models.user import User

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("adoptify-create-user")


async def create_user(
    email: str, rut: str, password: str, full_name: str, role: str, foundation_id: int | None = None
) -> None:
    """
    Crea un usuario con el rol indicado. Sirve para cuentas que no pueden
    registrarse solas desde la web, como las de fundación o administrador.
    """
    async with AsyncSessionLocal() as session:
        existing = await session.execute(select(User).where((User.email == email) | (User.rut == rut)))
        if existing.scalars().first() is not None:
            logger.info(f"Ya existe un usuario con el correo {email} o el RUT {rut}. No se hicieron cambios.")
            return

        session.add(User(
            email=email,
            rut=rut,
            hashed_password=hash_password(password),
            full_name=full_name,
            role=role,
            foundation_id=foundation_id,
            preferences={}
        ))
        await session.commit()
        logger.info(f"Usuario {email} creado con rol '{role}'.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Crear un usuario de Adoptify con un rol específico.")
    parser.add_argument("--email", required=True)
    parser.add_argument("--rut", required=True, help="Con o sin puntos, por ejemplo 12.345.678-5")
    parser.add_argument("--password", required=True)
    parser.add_argument("--name", required=True, help="Nombre completo o nombre de la fundación")
    parser.add_argument("--role", choices=["adopter", "foundation", "admin"], default="foundation")
    parser.add_argument("--foundation-id", type=int, help="ID de la fundación a la que pertenece la cuenta (rol foundation)")
    args = parser.parse_args()

    try:
        rut = normalize_rut(args.rut)
    except ValueError as exc:
        parser.error(str(exc))

    asyncio.run(create_user(args.email.strip().lower(), rut, args.password, args.name, args.role, args.foundation_id))
