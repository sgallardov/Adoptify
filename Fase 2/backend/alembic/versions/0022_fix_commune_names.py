"""fix_commune_names

Corrige la escritura de las comunas ya guardadas en animals.public_commune
("Aisen" -> "Aysén", "Chillan" -> "Chillán", ...), igual que el catálogo
communes.json. Solo cambia texto: no hay tablas nuevas ni puntos distintos.

Revision ID: 0022
Revises: 0021
"""
import sqlalchemy as sa
from alembic import op

from app.services.commune_renames import COMMUNE_RENAMES

revision = "0022"
down_revision = "0021"
branch_labels = None
depends_on = None

_UPDATE = sa.text("UPDATE animals SET public_commune = :new WHERE public_commune = :old")


def upgrade() -> None:
    for old, new in COMMUNE_RENAMES.items():
        op.execute(_UPDATE.bindparams(old=old, new=new))


def downgrade() -> None:
    for old, new in COMMUNE_RENAMES.items():
        op.execute(_UPDATE.bindparams(old=new, new=old))
