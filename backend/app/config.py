"""
Configuration loader for MetalCraft Cloud Backend on Render.
Reads environment variables for Gemini, Parallel, Grafana, database, and iOS security.
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env from backend root or workspace root if present
backend_root = Path(__file__).resolve().parent.parent
workspace_root = backend_root.parent

if (backend_root / ".env").exists():
    load_dotenv(backend_root / ".env")
elif (workspace_root / ".env").exists():
    load_dotenv(workspace_root / ".env")

ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", os.getenv("LOCAL_AGENT_PORT", "8080")))

# Core AI & Search Secrets (Server-Side Only)
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
PARALLEL_API_KEY = os.getenv("PARALLEL_API_KEY", "")

# Observability (Server-Side Only)
GRAFANA_URL = os.getenv("GRAFANA_URL", "http://localhost:3000")
GRAFANA_TOKEN = os.getenv("GRAFANA_TOKEN", "")

# Persistent Storage
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite+aiosqlite:///{backend_root}/metalcraft_state.db")

# iOS Security & Device Authentication
IOS_AUTH_SECRET = os.getenv("IOS_AUTH_SECRET", "metalcraft-device-auth-secret-key-2026")

# Official Demonstration Video Canonical URL
DEMO_VIDEO_URL = os.getenv(
    "DEMO_VIDEO_URL",
    "https://drive.google.com/file/d/10bRFWpuJU9U3TBOJX3nyBucbd00Othp3/view?usp=drive_link"
)

# CORS Allowed Origins
raw_cors = os.getenv("CORS_ALLOWED_ORIGINS", "*")
if raw_cors == "*":
    CORS_ALLOWED_ORIGINS = ["*"]
else:
    CORS_ALLOWED_ORIGINS = [origin.strip() for origin in raw_cors.split(",") if origin.strip()]
