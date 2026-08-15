"""
Configuration loader for MetalCraft Agent Backend.
Reads environment variables from .env for local Mac development or Google Cloud environment.
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env from project root if it exists
project_root = Path(__file__).resolve().parent.parent
dotenv_path = project_root / ".env"
if dotenv_path.exists():
    load_dotenv(dotenv_path)

HOST = os.getenv("LOCAL_AGENT_HOST", "0.0.0.0")
PORT = int(os.getenv("LOCAL_AGENT_PORT", "8080"))

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
PARALLEL_API_KEY = os.getenv("PARALLEL_API_KEY", "")

GRAFANA_URL = os.getenv("GRAFANA_URL", "http://localhost:3000")
GRAFANA_TOKEN = os.getenv("GRAFANA_TOKEN", "")

GOOGLE_CLOUD_PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT_ID", "")
GOOGLE_CLOUD_LOCATION = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
