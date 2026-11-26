"""add_foster_application_location

HU-AA: la postulación a hogar temporal guarda la ubicación del hogar para que cada fundación solo vea las
postulaciones a 10 km o menos de su sede. Es nullable: las postulaciones anteriores no tienen ubicación y
ninguna fundación las ve hasta que su dueño la edite o postule de nuevo.

Revision ID: 0024
Revises: 0023
"""
from alembic import op
import sqlalchemy as sa
from geoalchemy2 import Geometry

revision = "0024"
down_revision = "0023"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "foster_applications",
        sa.Column("location", Geometry(geometry_type="POINT", srid=4326, spatial_index=False), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("foster_applications", "location")
