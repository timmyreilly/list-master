"""initial schema: contributors, grocery_items, inbound_messages

Revision ID: 0001
Revises:
Create Date: 2026-04-09
"""

from typing import Sequence, Union

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

item_status = postgresql.ENUM("pending", "purchased", name="item_status", create_type=False)


def upgrade() -> None:
    item_status.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "contributors",
        sa.Column("id", sa.UUID(), nullable=False, default=sa.text("gen_random_uuid()")),
        sa.Column("phone_number", sa.String(length=20), nullable=False),
        sa.Column("display_name", sa.String(length=100), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("phone_number"),
    )
    op.create_index("ix_contributors_phone_number", "contributors", ["phone_number"])

    op.create_table(
        "grocery_items",
        sa.Column("id", sa.UUID(), nullable=False, default=sa.text("gen_random_uuid()")),
        sa.Column("raw_text", sa.Text(), nullable=False),
        sa.Column("display_text", sa.Text(), nullable=False),
        sa.Column("contributor_id", sa.UUID(), nullable=False),
        sa.Column(
            "status",
            item_status,
            nullable=False,
            server_default="pending",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["contributor_id"], ["contributors.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_grocery_items_contributor_id", "grocery_items", ["contributor_id"])
    op.create_index("ix_grocery_items_status", "grocery_items", ["status"])

    op.create_table(
        "inbound_messages",
        sa.Column("id", sa.UUID(), nullable=False, default=sa.text("gen_random_uuid()")),
        sa.Column("from_phone", sa.String(length=20), nullable=False),
        sa.Column("raw_body", sa.Text(), nullable=False),
        sa.Column("parsed_result", postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column(
            "processing_status",
            sa.String(length=20),
            nullable=False,
            server_default="received",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_inbound_messages_from_phone", "inbound_messages", ["from_phone"])
    op.create_index(
        "ix_inbound_messages_processing_status", "inbound_messages", ["processing_status"]
    )


def downgrade() -> None:
    op.drop_table("inbound_messages")
    op.drop_table("grocery_items")
    op.drop_table("contributors")
    item_status.drop(op.get_bind(), checkfirst=True)
