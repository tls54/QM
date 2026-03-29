FROM python:3.12-slim

WORKDIR /app

# Install dependencies first (layer caching — only re-runs if pyproject.toml changes)
COPY pyproject.toml .
RUN pip install --no-cache-dir .

# Copy application code and persisted vector index
COPY app/ app/
COPY chroma_db/ chroma_db/

EXPOSE 8000

# Use $PORT if injected by host (Railway etc.), otherwise default to 8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
