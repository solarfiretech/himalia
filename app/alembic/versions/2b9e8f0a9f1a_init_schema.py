"""init schema

Revision ID: 2b9e8f0a9f1a
Revises:
Create Date: 2026-02-03

"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "2b9e8f0a9f1a"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "devices",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column("type", sa.String(length=64), nullable=False),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.text("1")),
        sa.Column("endpoint", sa.String(length=2048), nullable=False),
        sa.Column("auth_mode", sa.String(length=16), nullable=True),
        sa.Column("auth_username", sa.String(length=128), nullable=True),
        sa.Column("auth_password", sa.String(length=256), nullable=True),
        sa.Column("poll_interval_s", sa.Integer(), nullable=False, server_default=sa.text("60")),
        sa.Column("timeout_ms", sa.Integer(), nullable=False, server_default=sa.text("5000")),
        sa.Column("tags", sa.JSON(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_poll_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_error", sa.Text(), nullable=True),
    )

    op.create_table(
        "readings",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("device_id", sa.String(length=36), sa.ForeignKey("devices.id", ondelete="CASCADE"), nullable=False),
        sa.Column("captured_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("value", sa.Text(), nullable=True),
        sa.Column("unit", sa.String(length=32), nullable=True),
        sa.Column("confidence", sa.Float(), nullable=True),
        sa.Column("success", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("source", sa.String(length=128), nullable=True),
        sa.Column("image_path", sa.Text(), nullable=True),
    )

    op.create_index("ix_readings_device_id_captured_at", "readings", ["device_id", "captured_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_readings_device_id_captured_at", table_name="readings")
    op.drop_table("readings")
    op.drop_table("devices")
