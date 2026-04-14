"""LLM-powered grocery message parser.

Uses OpenAI structured outputs to extract grocery items from free-text
WhatsApp messages. Falls back to raw-text line splitting when the API
is unavailable or returns an unparseable response.
"""

from __future__ import annotations

import logging
from typing import Optional

from openai import AsyncOpenAI, OpenAIError
from pydantic import BaseModel, Field

from app.config import settings

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Pydantic schemas (structured output)
# ---------------------------------------------------------------------------

class ParsedItem(BaseModel):
    """A single grocery item extracted from a message."""

    name: str = Field(description="Grocery item name, e.g. 'whole milk'")
    quantity: Optional[float] = Field(
        default=None, description="Numeric quantity, e.g. 2"
    )
    unit: Optional[str] = Field(
        default=None, description="Unit of measure, e.g. 'gallons', 'lbs', 'dozen'"
    )

    @property
    def display(self) -> str:
        """Human-readable display string."""
        parts: list[str] = []
        if self.quantity is not None:
            qty = int(self.quantity) if self.quantity == int(self.quantity) else self.quantity
            parts.append(str(qty))
        if self.unit:
            parts.append(self.unit)
        parts.append(self.name)
        return " ".join(parts)


class ParseResult(BaseModel):
    """Complete result of parsing a grocery message."""

    items: list[ParsedItem] = Field(default_factory=list)
    raw_text: str = Field(description="Original message text")
    used_fallback: bool = Field(
        default=False,
        description="True when LLM parsing failed and raw-text splitting was used",
    )


# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------

SYSTEM_PROMPT = (
    "You are a grocery list parser. Extract grocery items from the user's message. "
    "For each item, identify the name, optional quantity (as a number), and optional "
    "unit of measure. If a message contains no grocery items, return an empty list. "
    "Normalize item names to lowercase. Ignore greetings, thanks, and non-grocery text."
)


# ---------------------------------------------------------------------------
# Structured output schema for the OpenAI API
# ---------------------------------------------------------------------------

_ITEMS_SCHEMA = {
    "type": "json_schema",
    "json_schema": {
        "name": "grocery_items",
        "strict": True,
        "schema": {
            "type": "object",
            "properties": {
                "items": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "quantity": {"type": ["number", "null"]},
                            "unit": {"type": ["string", "null"]},
                        },
                        "required": ["name", "quantity", "unit"],
                        "additionalProperties": False,
                    },
                },
            },
            "required": ["items"],
            "additionalProperties": False,
        },
    },
}


# ---------------------------------------------------------------------------
# Client factory
# ---------------------------------------------------------------------------

def _get_client() -> AsyncOpenAI:
    return AsyncOpenAI(api_key=settings.openai_api_key)


# ---------------------------------------------------------------------------
# Fallback parser
# ---------------------------------------------------------------------------

def fallback_parse(text: str) -> ParseResult:
    """Split raw text into one item per non-empty line (or comma-separated segment)."""
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    # If a single line contains commas, split on commas instead
    if len(lines) <= 1 and "," in text:
        lines = [seg.strip() for seg in text.split(",") if seg.strip()]
    items = [ParsedItem(name=line.lower()) for line in lines if line]
    return ParseResult(items=items, raw_text=text, used_fallback=True)


# ---------------------------------------------------------------------------
# LLM parser
# ---------------------------------------------------------------------------

async def parse_grocery_message(
    text: str,
    *,
    client: AsyncOpenAI | None = None,
    model: str = "gpt-4o-mini",
) -> ParseResult:
    """Parse a grocery message into structured items.

    Calls the OpenAI API with structured output. On any failure
    (network, auth, malformed response) falls back to raw-text splitting
    so the pipeline never blocks on LLM availability.
    """
    if not settings.openai_api_key:
        logger.warning("No OpenAI API key configured — using fallback parser")
        return fallback_parse(text)

    _client = client or _get_client()

    try:
        response = await _client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": text},
            ],
            response_format=_ITEMS_SCHEMA,
            temperature=0.0,
        )

        import json

        raw_json = response.choices[0].message.content
        data = json.loads(raw_json)  # type: ignore[arg-type]

        items = [ParsedItem(**item) for item in data.get("items", [])]
        return ParseResult(items=items, raw_text=text, used_fallback=False)

    except (OpenAIError, KeyError, IndexError, ValueError, TypeError) as exc:
        logger.warning("LLM parsing failed (%s), falling back to raw-text", exc)
        return fallback_parse(text)
