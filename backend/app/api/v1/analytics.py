"""
Analytics, Telemetry Ingestion, and Observability API (/api/v1/analytics & /api/v1/telemetry).
"""

from typing import Union, List, Dict, Any
from fastapi import APIRouter
from app.telemetry.grafana_client import record_telemetry, query_observability
from app.storage.database import DatabaseRepository
from app.websocket.connection_manager import manager

analytics_router = APIRouter(tags=["Analytics & Telemetry"])


@analytics_router.get("/analytics")
@analytics_router.get("/observability")
async def get_analytics():
    """Returns real-time GPU frame budget and latency metrics for Web and iOS analytics."""
    observability_data = query_observability("latency")
    devices = await DatabaseRepository.list_active_devices()
    jobs = await DatabaseRepository.list_generation_jobs(limit=10)
    
    return {
        "observability": observability_data,
        "activeDevicesCount": len([d for d in devices if manager.is_ios_connected(d.session_id)]),
        "recentGenerationsCount": len(jobs),
        "targetFps": 30.0
    }


@analytics_router.post("/telemetry")
async def ingest_telemetry(events: Union[List[Dict[str, Any]], Dict[str, Any]]):
    """Ingests GPU execution telemetry, sanitizes tokens, and buffers metrics."""
    if isinstance(events, list):
        for ev in events:
            record_telemetry(ev)
            await DatabaseRepository.record_telemetry(ev)
        count = len(events)
    elif isinstance(events, dict):
        record_telemetry(events)
        await DatabaseRepository.record_telemetry(events)
        count = 1
    else:
        count = 0

    return {"status": "recorded", "count": count}
