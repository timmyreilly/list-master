"""Unit tests for the LLM grocery message parser."""

from __future__ import annotations

import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.llm_parser import (
    ParsedItem,
    ParseResult,
    fallback_parse,
    parse_grocery_message,
)

# ---------------------------------------------------------------------------
# ParsedItem schema tests
# ---------------------------------------------------------------------------

class TestParsedItem:
    def test_minimal_item(self):
        item = ParsedItem(name="milk")
        assert item.name == "milk"
        assert item.quantity is None
        assert item.unit is None

    def test_full_item(self):
        item = ParsedItem(name="whole milk", quantity=2, unit="gallons")
        assert item.name == "whole milk"
        assert item.quantity == 2
        assert item.unit == "gallons"

    def test_display_name_only(self):
        assert ParsedItem(name="bread").display == "bread"

    def test_display_with_quantity(self):
        assert ParsedItem(name="eggs", quantity=12).display == "12 eggs"

    def test_display_with_quantity_and_unit(self):
        assert ParsedItem(name="milk", quantity=2, unit="gallons").display == "2 gallons milk"

    def test_display_fractional_quantity(self):
        assert ParsedItem(name="butter", quantity=0.5, unit="lbs").display == "0.5 lbs butter"

    def test_display_integer_quantity_no_decimal(self):
        item = ParsedItem(name="apples", quantity=3.0)
        assert item.display == "3 apples"


class TestParseResult:
    def test_empty_result(self):
        result = ParseResult(items=[], raw_text="hello", used_fallback=False)
        assert result.items == []
        assert result.raw_text == "hello"
        assert result.used_fallback is False

    def test_result_with_items(self):
        items = [ParsedItem(name="milk"), ParsedItem(name="bread")]
        result = ParseResult(items=items, raw_text="milk and bread")
        assert len(result.items) == 2


# ---------------------------------------------------------------------------
# Fallback parser tests
# ---------------------------------------------------------------------------

class TestFallbackParse:
    def test_single_line(self):
        result = fallback_parse("Milk")
        assert len(result.items) == 1
        assert result.items[0].name == "milk"
        assert result.used_fallback is True

    def test_multi_line(self):
        result = fallback_parse("Milk\nBread\nEggs")
        assert len(result.items) == 3
        names = [i.name for i in result.items]
        assert names == ["milk", "bread", "eggs"]

    def test_comma_separated(self):
        result = fallback_parse("milk, bread, eggs")
        assert len(result.items) == 3
        names = [i.name for i in result.items]
        assert names == ["milk", "bread", "eggs"]

    def test_empty_string(self):
        result = fallback_parse("")
        assert len(result.items) == 0
        assert result.used_fallback is True

    def test_blank_lines_stripped(self):
        result = fallback_parse("Milk\n\n  \nBread\n")
        assert len(result.items) == 2

    def test_preserves_raw_text(self):
        raw = "Hello! I need milk"
        result = fallback_parse(raw)
        assert result.raw_text == raw

    def test_items_lowercased(self):
        result = fallback_parse("WHOLE MILK\nOrganic Eggs")
        assert result.items[0].name == "whole milk"
        assert result.items[1].name == "organic eggs"


# ---------------------------------------------------------------------------
# LLM parser tests (mocked OpenAI)
# ---------------------------------------------------------------------------

def _mock_openai_response(items_data: list[dict]) -> MagicMock:
    """Build a mock ChatCompletion response."""
    payload = json.dumps({"items": items_data})
    choice = MagicMock()
    choice.message.content = payload
    response = MagicMock()
    response.choices = [choice]
    return response


class TestParseGroceryMessage:
    @pytest.mark.asyncio
    async def test_successful_parse(self):
        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(
            return_value=_mock_openai_response([
                {"name": "milk", "quantity": 2, "unit": "gallons"},
                {"name": "bread", "quantity": 1, "unit": None},
            ])
        )

        with patch("app.services.llm_parser.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test"
            result = await parse_grocery_message(
                "I need 2 gallons of milk and a loaf of bread",
                client=mock_client,
            )

        assert len(result.items) == 2
        assert result.items[0].name == "milk"
        assert result.items[0].quantity == 2
        assert result.items[0].unit == "gallons"
        assert result.items[1].name == "bread"
        assert result.used_fallback is False

    @pytest.mark.asyncio
    async def test_empty_items_from_llm(self):
        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(
            return_value=_mock_openai_response([])
        )

        with patch("app.services.llm_parser.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test"
            result = await parse_grocery_message("hello there!", client=mock_client)
        assert len(result.items) == 0
        assert result.used_fallback is False

    @pytest.mark.asyncio
    async def test_fallback_on_api_error(self):
        from openai import APIConnectionError

        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(
            side_effect=APIConnectionError(request=MagicMock())
        )

        with patch("app.services.llm_parser.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test"
            result = await parse_grocery_message("milk\nbread", client=mock_client)
        assert result.used_fallback is True
        assert len(result.items) == 2

    @pytest.mark.asyncio
    async def test_fallback_on_malformed_json(self):
        choice = MagicMock()
        choice.message.content = "not json at all"
        response = MagicMock()
        response.choices = [choice]

        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(return_value=response)

        with patch("app.services.llm_parser.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test"
            result = await parse_grocery_message("eggs", client=mock_client)
        assert result.used_fallback is True
        assert len(result.items) == 1

    @pytest.mark.asyncio
    async def test_fallback_when_no_api_key(self):
        with patch("app.services.llm_parser.settings") as mock_settings:
            mock_settings.openai_api_key = ""
            result = await parse_grocery_message("milk and eggs")
            assert result.used_fallback is True

    @pytest.mark.asyncio
    async def test_preserves_raw_text(self):
        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(
            return_value=_mock_openai_response([{"name": "milk", "quantity": None, "unit": None}])
        )
        raw = "Please get some milk"
        with patch("app.services.llm_parser.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test"
            result = await parse_grocery_message(raw, client=mock_client)
        assert result.raw_text == raw

    @pytest.mark.asyncio
    async def test_fallback_on_empty_choices(self):
        response = MagicMock()
        response.choices = []

        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(return_value=response)

        with patch("app.services.llm_parser.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test"
            result = await parse_grocery_message("eggs", client=mock_client)
        assert result.used_fallback is True

    @pytest.mark.asyncio
    async def test_custom_model_param(self):
        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(
            return_value=_mock_openai_response([])
        )
        with patch("app.services.llm_parser.settings") as mock_settings:
            mock_settings.openai_api_key = "sk-test"
            await parse_grocery_message("test", client=mock_client, model="gpt-4o")
        call_kwargs = mock_client.chat.completions.create.call_args.kwargs
        assert call_kwargs["model"] == "gpt-4o"
