"""
Health check and provider status diagnostics endpoints (/api/v1/health).
"""

import time
import socket
from fastapi import APIRouter
from app.config import ENVIRONMENT, GEMINI_API_KEY
from app.agents.parallel_client import test_connection as test_parallel
from app.telemetry.grafana_client import get_grafana_health
from app.websocket.connection_manager import manager

health_router = APIRouter()


@health_router.get("/health")
async def health_check():
    """Returns comprehensive health status of the Render control plane and connected providers."""
    parallel_status = test_parallel()
    grafana_status = get_grafana_health()
    
    gemini_status = {
        "status": "PASS" if bool(GEMINI_API_KEY) else "CONFIGURED_LOCAL",
        "service": "Google Gemini 2.5 Flash",
        "configured": bool(GEMINI_API_KEY),
        "serverSideOnly": True
    }

    connected_ios_count = len(manager.active_ios_connections)
    
    return {
        "status": "healthy",
        "service": "MetalCraft Cloud Control Plane",
        "version": "1.0.0",
        "environment": ENVIRONMENT,
        "hostname": socket.gethostname(),
        "timestamp": int(time.time()),
        "providers": {
            "gemini": gemini_status,
            "parallel": parallel_status,
            "grafana": grafana_status
        },
        "devices": {
            "connectedCount": connected_ios_count,
            "status": "CONNECTED" if connected_ios_count > 0 else "WAITING_FOR_DEVICE"
        }
    }
