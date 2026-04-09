"""Grocery list routes — full page and HTMX partials."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_session
from app.models.grocery_item import GroceryItem, ItemStatus

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")


def _split_items(items: list[GroceryItem]) -> tuple[list[GroceryItem], list[GroceryItem]]:
    """Split items into unchecked and checked, each sorted by created_at desc."""
    unchecked = sorted(
        [i for i in items if i.status == ItemStatus.pending],
        key=lambda i: i.created_at,
        reverse=True,
    )
    checked = sorted(
        [i for i in items if i.status == ItemStatus.purchased],
        key=lambda i: i.created_at,
        reverse=True,
    )
    return unchecked, checked


async def _fetch_all_items(session: AsyncSession) -> list[GroceryItem]:
    result = await session.execute(
        select(GroceryItem).options(selectinload(GroceryItem.contributor))
    )
    return list(result.scalars().all())


@router.get("/", response_class=HTMLResponse)
async def grocery_list(request: Request, session: AsyncSession = Depends(get_session)):
    """Full grocery list page."""
    items = await _fetch_all_items(session)
    unchecked, checked = _split_items(items)
    return templates.TemplateResponse(
        request,
        "list.html",
        {"unchecked_items": unchecked, "checked_items": checked},
    )


@router.patch("/items/{item_id}/toggle", response_class=HTMLResponse)
async def toggle_item(
    request: Request,
    item_id: uuid.UUID,
    session: AsyncSession = Depends(get_session),
):
    """Toggle an item between pending and purchased, return updated row partial."""
    result = await session.execute(
        select(GroceryItem)
        .options(selectinload(GroceryItem.contributor))
        .where(GroceryItem.id == item_id)
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Item not found")

    item.status = ItemStatus.purchased if item.status == ItemStatus.pending else ItemStatus.pending
    await session.commit()
    await session.refresh(item)

    return templates.TemplateResponse(
        request,
        "partials/item_row.html",
        {"item": item},
    )
