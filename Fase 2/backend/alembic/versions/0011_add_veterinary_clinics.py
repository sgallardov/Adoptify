"""add_veterinary_clinics

Clínicas veterinarias para emergencias (pines con cruz roja en el mapa), importadas de OpenStreetMap.

Revision ID: 0011
Revises: 0010
Create Date: 2026-11-09 12:00:00.000000

"""
from alembic import op
import geoalchemy2
import sqlalchemy as sa

revision = "0011"
down_revision = "0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # GeoAlchemy2 crea automáticamente el índice espacial GiST idx_veterinary_clinics_location
    op.create_table(
        "veterinary_clinics",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("osm_id", sa.String(length=40), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("address", sa.String(length=255), nullable=True),
        sa.Column("commune", sa.String(length=100), nullable=True),
        sa.Column("phone", sa.String(length=50), nullable=True),
        sa.Column("opening_hours", sa.String(length=255), nullable=True),
        sa.Column("emergency", sa.Boolean(), nullable=False),
        sa.Column(
            "location",
            geoalchemy2.types.Geometry(geometry_type="POINT", srid=4326, from_text="ST_GeomFromEWKT", name="geometry"),
            nullable=False,
        ),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("osm_id"),
    )
    # Sin RLS, la API pública de Supabase expondría la tabla (ver 0009)
    op.execute("ALTER TABLE veterinary_clinics ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.drop_table("veterinary_clinics")
