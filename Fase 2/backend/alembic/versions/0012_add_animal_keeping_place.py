"""add_animal_keeping_place

Información privada del lugar de resguardo de cada animal. No se geocodifica:
``location`` conserva su función de punto privado de HU-04 y la dirección es
una referencia de texto para la gestión interna.
"""
from alembic import op
import sqlalchemy as sa


revision = "0012"
down_revision = "0011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Nullable para no invalidar los animales creados antes de HU-A.
    op.add_column("animals", sa.Column("keeping_place_type", sa.String(length=30), nullable=True))
    op.add_column("animals", sa.Column("keeping_place_address", sa.String(length=255), nullable=True))
    op.create_check_constraint(
        "ck_animals_keeping_place_type",
        "animals",
        "keeping_place_type IS NULL OR keeping_place_type IN ('refugio', 'hogar_temporal')",
    )
    # La tabla ya tenía RLS, pero se declara de nuevo en esta migración para que el requisito
    # se mantenga explícito al extender información sensible.
    op.execute("ALTER TABLE animals ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.drop_constraint("ck_animals_keeping_place_type", "animals", type_="check")
    op.drop_column("animals", "keeping_place_address")
    op.drop_column("animals", "keeping_place_type")
