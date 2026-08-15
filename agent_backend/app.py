"""
MetalCraft Agent Backend Application.
Flask REST API server for local Mac development and Google Cloud Run deployment.
"""

import os
import sys
import uuid
import socket
import logging
import subprocess
from flask import Flask, request, jsonify

# Add directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import HOST, PORT
from agent.director import CreativeDirector
from agent.tools import grafana_client

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("MetalCraftBackend")

app = Flask(__name__)
director = CreativeDirector()

# Bonjour registration process handle
_bonjour_proc = None

def start_bonjour_advertisement():
    """Advertises the MetalCraft agent backend via macOS Bonjour (ZeroConf)."""
    global _bonjour_proc
    if sys.platform == "darwin":
        try:
            _bonjour_proc = subprocess.Popen(
                ["/usr/bin/dns-sd", "-R", "MetalCraft Agent", "_metalcraft._tcp", "local", str(PORT)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            logger.info(f"[AgentConnection] Bonjour service registered: _metalcraft._tcp on port {PORT}")
        except Exception as e:
            logger.warning(f"[AgentConnection] Could not start Bonjour advertisement: {e}")

@app.route("/health", methods=["GET"])
def health():
    client_ip = request.remote_addr
    logger.info(f"[AgentConnection] Health check requested from client: {client_ip}")
    return jsonify({
        "status": "healthy",
        "service": "MetalCraft Agent Backend",
        "version": "1.0.0",
        "hostname": socket.gethostname()
    }), 200

@app.route("/api/v1/agent/create", methods=["POST"])
def agent_create():
    client_ip = request.remote_addr
    try:
        data = request.get_json(force=True)
        if not data:
            return jsonify({"error": "Missing JSON request body"}), 400

        prompt = data.get("prompt", "")
        media_metadata = data.get("mediaMetadata", {})
        thumbnail_base64 = data.get("thumbnailBase64")
        preferences = data.get("preferences")
        request_id = data.get("requestId", str(uuid.uuid4()))

        logger.info(f"[AgentConnection] Creative request '{prompt}' from {client_ip} for {media_metadata.get('type', 'image')}")

        result = director.formulate_creative_plan(
            prompt=prompt,
            media_metadata=media_metadata,
            thumbnail_base64=thumbnail_base64,
            preferences=preferences
        )

        response_payload = {
            "requestId": request_id,
            "agentState": result.get("agentState", "Waiting for User Approval"),
            "editPlan": result.get("editPlan"),
            "reasoning": result.get("reasoning"),
            "researchContext": result.get("researchContext"),
            "confidence": result.get("confidence", 0.9),
            "estimatedProcessingTimeMs": result.get("estimatedProcessingTimeMs", 150.0)
        }

        logger.info(f"[AgentConnection] Response dispatched for request {request_id} (confidence: {response_payload['confidence']})")
        return jsonify(response_payload), 200

    except Exception as e:
        logger.error(f"[AgentConnection] Error formulating creative plan: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500

@app.route("/api/v1/telemetry", methods=["POST"])
def receive_telemetry():
    client_ip = request.remote_addr
    try:
        events = request.get_json(force=True)
        if not events:
            return jsonify({"status": "no_events"}), 200

        if isinstance(events, list):
            for event in events:
                grafana_client.record_telemetry(event)
            logger.info(f"[AgentConnection] Recorded {len(events)} telemetry events from {client_ip}")
        elif isinstance(events, dict):
            grafana_client.record_telemetry(events)
            logger.info(f"[AgentConnection] Recorded 1 telemetry event from {client_ip}")

        return jsonify({"status": "recorded", "count": len(events) if isinstance(events, list) else 1}), 200

    except Exception as e:
        logger.error(f"[AgentConnection] Error recording telemetry: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500

@app.route("/api/v1/observability", methods=["GET"])
def get_observability():
    query_type = request.args.get("query_type", "latency")
    metrics = grafana_client.query_observability(query_type)
    return jsonify(metrics), 200

if __name__ == "__main__":
    start_bonjour_advertisement()
    logger.info(f"==================================================")
    logger.info(f"  MetalCraft Agent Backend Started")
    logger.info(f"  Host: {HOST} | Port: {PORT}")
    logger.info(f"  Local Hostname: {socket.gethostname()}")
    logger.info(f"==================================================")
    app.run(host=HOST, port=PORT, debug=False)
