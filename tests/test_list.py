"""Tests for the grocery list HTMX UI — GET / and PATCH /items/{id}/toggle."""

import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

from fastapi.testclient import TestClient

from app.database import get_session
from app.main import app
from app.models.grocery_item import ItemStatus


@dataclass
class FakeContributor:
    display_name: str = "Alice"


@dataclass
class FakeItem:
    """Lightweight stand-in for GroceryItem (no SQLAlchemy state needed)."""

    id: uuid.UUID = field(default_factory=uuid.uuid4)
    raw_text: str = "Milk"
    display_text: str = "Milk"
    status: ItemStatus = ItemStatus.pending
    created_at: datetime = field(
        default_factory=lambda: datetime(2026, 4, 9, 12, 0, tzinfo=timezone.utc)
    )
    updated_at: datetime = field(
        default_factory=lambda: datetime(2026, 4, 9, 12, 0, tzinfo=timezone.utc)
    )
    contributor: FakeContributor = field(default_factory=FakeContributor)


_UNSET = object()


def _mock_session(items=None, find_item=_UNSET):
    """Build a mock AsyncSession. Result methods are sync (like real SQLAlchemy)."""
    session = AsyncMock()

    result = MagicMock()
    if items is not None:
        result.scalars.return_value.all.return_value = items
    if find_item is not _UNSET:
        result.scalar_one_or_none.return_value = find_item
    # execute is async, but result accessors are sync
    session.execute.return_value = result
    return session


def _override_session(items=None, find_item=_UNSET):
    """Return a FastAPI dependency override for get_session."""

    async def _dep():
        yield _mock_session(items=items, find_item=find_item)

    return _dep


client = TestClient(app)


class TestGetGroceryList:
    """GET / returns 200 with grocery list page."""

    def test_empty_list_returns_200(self):
        app.dependency_overrides[get_session] = _override_session(items=[])
        try:
            resp = client.get("/")
        finally:
            app.dependency_overrides.clear()
        assert resp.status_code == 200
        assert "List Master" in resp.text
        assert "No items on the list yet." in resp.text

    def test_list_with_items_returns_200(self):
        pending = FakeItem(display_text="Bread", status=ItemStatus.pending)
        purchased = FakeItem(
            display_text="Eggs",
            status=ItemStatus.purchased,
            contributor=FakeContributor("Bob"),
        )
        app.dependency_overrides[get_session] = _override_session(items=[pending, purchased])
        try:
            resp = client.get("/")
        finally:
            app.dependency_overrides.clear()
        assert resp.status_code == 200
        assert "Bread" in resp.text
        assert "Eggs" in resp.text
        assert "item-checked" in resp.text


class TestToggleItem:
    """PATCH /items/{id}/toggle toggles item status."""

    def test_toggle_pending_to_purchased(self):
        item_id = uuid.uuid4()
        item = FakeItem(id=item_id, display_text="Milk", status=ItemStatus.pending)
        app.dependency_overrides[get_session] = _override_session(find_item=item)
        try:
            resp = client.patch(f"/items/{item_id}/toggle")
        finally:
            app.dependency_overrides.clear()
        assert resp.status_code == 200
        assert item.status == ItemStatus.purchased
        assert "item-checked" in resp.text

    def test_toggle_purchased_to_pending(self):
        item_id = uuid.uuid4()
        item = FakeItem(id=item_id, display_text="Milk", status=ItemStatus.purchased)
        app.dependency_overrides[get_session] = _override_session(find_item=item)
        try:
            resp = client.patch(f"/items/{item_id}/toggle")
        finally:
            app.dependency_overrides.clear()
        assert resp.status_code == 200
        assert item.status == ItemStatus.pending
        assert "item-checked" not in resp.text

    def test_toggle_nonexistent_item_returns_404(self):
        fake_id = uuid.uuid4()
        app.dependency_overrides[get_session] = _override_session(find_item=None)
        try:
            resp = client.patch(f"/items/{fake_id}/toggle")
        finally:
            app.dependency_overrides.clear()
        assert resp.status_code == 404
