"""
MetalCraft Agent Backend Application.
Flask REST API server for local Mac development and Google Cloud Run deployment.
"""

import os
import sys
import uuid
import logging
from flask import Flask, request, jsonify

# Add directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import HOST, PORT
from agent.director import CreativeDirector
from agent.tools import grafana_client

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

app = Flask(__name__)
director = CreativeDirector()

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "healthy",
        "service": "MetalCraft Agent Backend",
        "version": "1.0.0"
    }), 200

@app.route("/api/v1/agent/create", methods=["POST"])
def agent_create():
    try:
        data = request.get_json(force=True)
        if not data:
            return jsonify({"error": "Missing JSON request body"}), 400

        prompt = data.get("prompt", "")
        media_metadata = data.get("mediaMetadata", {})
        thumbnail_base64 = data.get("thumbnailBase64")
        preferences = data.get("preferences")
        request_id = data.get("requestId", str(uuid.uuid4()))

        logger.info(f"Received creative prompt: '{prompt}' for media type: {media_metadata.get('type', 'image')}")

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

        return jsonify(response_payload), 200

    except Exception as e:
        logger.error(f"Error formulating creative plan: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500

@app.route("/api/v1/telemetry", methods=["POST"])
def receive_telemetry():
    try:
        events = request.get_json(force=True)
        if not events:
            return jsonify({"status": "no_events"}), 200

        if isinstance(events, list):
            for event in events:
                grafana_client.record_telemetry(event)
            logger.info(f"Recorded {len(events)} telemetry events from MetalCraft.")
        elif isinstance(events, dict):
            grafana_client.record_telemetry(events)
            logger.info("Recorded 1 telemetry event from MetalCraft.")

        return jsonify({"status": "recorded", "count": len(events) if isinstance(events, list) else 1}), 200

    except Exception as e:
        logger.error(f"Error recording telemetry: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500

@app.route("/api/v1/observability", methods=["GET"])
def get_observability():
    query_type = request.args.get("query_type", "latency")
    metrics = grafana_client.query_observability(query_type)
    return jsonify(metrics), 200

if __name__ == "__main__":
    logger.info(f"Starting MetalCraft Agent Backend on {HOST}:{PORT}")
    app.run(host=HOST, port=PORT, debug=False)
