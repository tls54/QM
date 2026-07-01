from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.database import Base, engine
from app.models import db as db_models  # noqa: F401 (registers ORM models with Base)
from app.routers import health, ask, models, inventory


@asynccontextmanager
async def lifespan(app: FastAPI):
    # No Alembic yet — create any missing tables on startup.
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="QM Backend",
    description="First aid and kit management AI assistant API",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(health.router)
app.include_router(ask.router)
app.include_router(models.router)
app.include_router(inventory.router)
