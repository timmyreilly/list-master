"""FastAPI application entrypoint."""

from fastapi import FastAPI

from app.routers.list import router as list_router

app = FastAPI(title="List Master", version="0.1.0")
app.include_router(list_router)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
