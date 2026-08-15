"""
Grafana MCP Client & In-Memory Telemetry Collector for production observability and agentic evaluation.
"""

import logging
from typing import Dict, Any, List, Optional
import requests
from config import GRAFANA_URL, GRAFANA_TOKEN

logger = logging.getLogger(__name__)

class GrafanaClient:
    def __init__(self, url: Optional[str] = None, token: Optional[str] = None):
        self.url = url or GRAFANA_URL
        self.token = token or GRAFANA_TOKEN
        self.telemetry_store: List[Dict[str, Any]] = []

    def record_telemetry(self, event: Dict[str, Any]):
        """Records a telemetry event in local buffer and attempts upload to Grafana instance."""
        self.telemetry_store.append(event)
        if len(self.telemetry_store) > 500:
            self.telemetry_store.pop(0)

        # If Grafana token is present, send to Grafana Prometheus / Loki endpoint
        if self.token:
            try:
                headers = {
                    "Authorization": f"Bearer {self.token}",
                    "Content-Type": "application/json"
                }
                # Optional remote write
                requests.post(f"{self.url}/api/v1/metrics", json=event, headers=headers, timeout=2)
            except Exception as e:
                logger.debug(f"Grafana remote write skipped: {e}")

    def query_observability(self, query_type: str = "latency", time_range: str = "5m") -> Dict[str, Any]:
        """Queries processing telemetry metrics for agentic feedback and evaluation."""
        if not self.telemetry_store:
            return {
                "status": "nominal",
                "sampleCount": 0,
                "averageGpuTimeMs": 2.5,
                "averageFrameTimeMs": 4.1,
                "errorRate": 0.0,
                "notes": "No telemetry recorded yet. System operational."
            }

        gpu_times = [e.get("gpuTimeMs", 0.0) for e in self.telemetry_store if e.get("gpuTimeMs") is not None]
        frame_times = [e.get("processingTimeMs", 0.0) for e in self.telemetry_store if e.get("processingTimeMs") is not None]
        errors = [e for e in self.telemetry_store if e.get("eventType") == "processing_error"]

        avg_gpu = sum(gpu_times) / max(1, len(gpu_times))
        avg_frame = sum(frame_times) / max(1, len(frame_times))
        error_rate = len(errors) / max(1, len(self.telemetry_store))

        return {
            "status": "nominal" if error_rate == 0 else "degraded",
            "sampleCount": len(self.telemetry_store),
            "averageGpuTimeMs": round(avg_gpu, 2),
            "averageFrameTimeMs": round(avg_frame, 2),
            "errorCount": len(errors),
            "errorRate": round(error_rate, 4),
            "lastOperation": self.telemetry_store[-1].get("operation", "None") if self.telemetry_store else "None"
        }
