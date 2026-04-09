"""InboundMessage model — raw WhatsApp messages received via webhook."""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, Text, func
from sqlalchemy.dialects.postgresql import JSON, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class InboundMessage(Base):
    __tablename__ = "inbound_messages"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    from_phone: Mapped[str] = mapped_column(
        String(20), nullable=False, index=True
    )
    raw_body: Mapped[str] = mapped_column(Text, nullable=False)
    parsed_result: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    processing_status: Mapped[str] = mapped_column(
        String(20), default="received", nullable=False, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
