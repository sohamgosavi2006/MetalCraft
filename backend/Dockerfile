# ============================================================
# MetalCraft Render Cloud Control Plane — Production Dockerfile
# ============================================================
FROM python:3.11-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8080

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy backend requirements and install Python packages
COPY backend/requirements.txt /app/requirements.txt
RUN pip install --upgrade pip && pip install -r /app/requirements.txt

# Copy backend application code
COPY backend /app/backend
COPY web /app/web

WORKDIR /app/backend

# Create directory for persistent SQLite storage
RUN mkdir -p /app/backend/data

EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT}/api/v1/health || exit 1

# Start FastAPI server
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
