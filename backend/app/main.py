"""
MetalCraft Cloud Control Plane — FastAPI Entrypoint.
Orchestrates Gemini Creative Director, Parallel research, Grafana telemetry,
SQLite metadata persistence, and real-time WebSockets with iOS clients.
"""

import os
import sys
import logging
from pathlib import Path
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

# Ensure app package is in path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import HOST, PORT, ENVIRONMENT, CORS_ALLOWED_ORIGINS
from app.storage.database import init_db
from app.api.v1.health import health_router
from app.api.v1.ios import ios_router
from app.api.v1.generations import generations_router
from app.api.v1.agent import agent_router
from app.api.v1.projects import projects_router
from app.api.v1.audit import audit_router
from app.api.v1.analytics import analytics_router
from app.websocket.ws_routes import ws_router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [%(name)s] %(message)s"
)
logger = logging.getLogger("MetalCraftApp")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initializes persistent storage schema on startup."""
    logger.info(f"Initializing MetalCraft Control Plane ({ENVIRONMENT})...")
    await init_db()
    logger.info("SQLite metadata database initialized successfully.")
    yield
    logger.info("Shutting down MetalCraft Control Plane.")


app = FastAPI(
    title="MetalCraft Agentic Media Platform",
    version="1.0.0",
    description="Production Cloud Control Plane for Gemini Agent Orchestration, Parallel Research, and Apple Metal GPU Rendering.",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ALLOWED_ORIGINS if CORS_ALLOWED_ORIGINS != ["*"] else ["*"],
    allow_credentials=True if CORS_ALLOWED_ORIGINS != ["*"] else False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount REST API Routers under /api/v1 and aliases
app.include_router(health_router, prefix="/api/v1")
app.include_router(health_router, prefix="/api")
app.include_router(ios_router, prefix="/api/v1")
app.include_router(generations_router, prefix="/api/v1")
app.include_router(agent_router, prefix="/api/v1")
app.include_router(projects_router, prefix="/api/v1")
app.include_router(audit_router, prefix="/api/v1")
app.include_router(analytics_router, prefix="/api/v1")
app.include_router(ws_router)

# Mount Web Companion Static Files
web_dir = Path(__file__).resolve().parent.parent.parent / "web"
if web_dir.exists():
    app.mount("/static", StaticFiles(directory=str(web_dir)), name="static")

    @app.get("/", include_in_schema=False)
    async def serve_root():
        index_path = web_dir / "index.html"
        if index_path.exists():
            return FileResponse(str(index_path))
        return {"service": "MetalCraft Cloud Control Plane", "status": "running"}


if __name__ == "__main__":
    import uvicorn
    logger.info(f"Starting server on {HOST}:{PORT}")
    uvicorn.run("app.main:app", host=HOST, port=PORT, reload=False)
