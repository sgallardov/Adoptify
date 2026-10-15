from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.ext.asyncio import AsyncAttrs

class Base(AsyncAttrs, DeclarativeBase):
    """
    Clase base declarativa para SQLAlchemy 2.0 con soporte para atributos asíncronos.
    """
    pass
