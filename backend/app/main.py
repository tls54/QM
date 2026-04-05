from fastapi import FastAPI
from app.routers import health, ask, models

app = FastAPI(
    title="QM Backend",
    description="First aid and kit management AI assistant API",
    version="0.1.0",
)

app.include_router(health.router)
app.include_router(ask.router)
app.include_router(models.router)
