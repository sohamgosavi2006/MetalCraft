"""
MetalCraft Agent Backend Application.
Flask REST API server for local Mac development and Google Cloud Run deployment.
"""

import os
import sys
import uuid
import socket
import logging
import time
import subprocess
from flask import Flask, request, jsonify, render_template_string

# Add directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import HOST, PORT, GEMINI_API_KEY, PARALLEL_API_KEY, GRAFANA_URL, GRAFANA_TOKEN
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

HOME_HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MetalCraft Agent Backend</title>
    <style>
        :root {
            --bg: #0d1117;
            --card-bg: #161b22;
            --border: #30363d;
            --text: #c9d1d9;
            --text-heading: #f0f6fc;
            --purple: #a371f7;
            --green: #3fb950;
            --blue: #58a6ff;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--bg);
            color: var(--text);
            margin: 0;
            padding: 40px 20px;
            display: flex;
            justify-content: center;
        }
        .container {
            max-width: 780px;
            width: 100%;
        }
        .header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 24px;
            padding-bottom: 16px;
            border-bottom: 1px solid var(--border);
        }
        .title-group h1 {
            color: var(--text-heading);
            font-size: 26px;
            margin: 0 0 6px 0;
        }
        .title-group p {
            margin: 0;
            color: #8b949e;
            font-size: 14px;
        }
        .badge-live {
            background: rgba(63, 185, 80, 0.15);
            color: var(--green);
            border: 1px solid rgba(63, 185, 80, 0.4);
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .badge-live::before {
            content: "";
            width: 8px;
            height: 8px;
            background: var(--green);
            border-radius: 50%;
            display: inline-block;
        }
        .card {
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
        }
        .card h2 {
            font-size: 16px;
            color: var(--text-heading);
            margin-top: 0;
            margin-bottom: 14px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 12px;
        }
        .item {
            background: #0d1117;
            padding: 12px;
            border-radius: 8px;
            border: 1px solid var(--border);
        }
        .item-label {
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: #8b949e;
            margin-bottom: 4px;
        }
        .item-value {
            font-size: 14px;
            font-weight: 600;
            color: var(--text-heading);
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
        }
        .status-pill {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 500;
        }
        .pill-active { background: rgba(63, 185, 80, 0.2); color: var(--green); }
        .pill-purple { background: rgba(163, 113, 247, 0.2); color: var(--purple); }
        .pill-blue { background: rgba(88, 166, 255, 0.2); color: var(--blue); }
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }
        th, td {
            text-align: left;
            padding: 10px 12px;
            border-bottom: 1px solid var(--border);
        }
        th {
            color: #8b949e;
            font-weight: 500;
        }
        td code {
            background: #0d1117;
            padding: 2px 6px;
            border-radius: 4px;
            color: var(--purple);
            font-family: ui-monospace, monospace;
        }
        a {
            color: var(--blue);
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="title-group">
                <h1>MetalCraft Agent Backend</h1>
                <p>Local AI Creative Director, Parallel Research & Grafana Observability Server</p>
            </div>
            <div class="badge-live">Online & Ready</div>
        </div>

        <div class="card">
            <h2>⚡ Connection Endpoints for iPhone 11</h2>
            <div class="grid">
                <div class="item">
                    <div class="item-label">iPhone Hotspot LAN</div>
                    <div class="item-value">http://172.20.10.4:{{ port }}</div>
                </div>
                <div class="item">
                    <div class="item-label">Bonjour Localhost</div>
                    <div class="item-value">http://{{ hostname }}:{{ port }}</div>
                </div>
                <div class="item">
                    <div class="item-label">Mac Localhost</div>
                    <div class="item-value">http://127.0.0.1:{{ port }}</div>
                </div>
            </div>
        </div>

        <div class="card">
            <h2>🤖 Agentic Services</h2>
            <table>
                <tr>
                    <th>Service</th>
                    <th>Model / Provider</th>
                    <th>Status</th>
                </tr>
                <tr>
                    <td><strong>Gemini Creative Director</strong></td>
                    <td><code>gemini-2.5-flash</code></td>
                    <td><span class="status-pill pill-purple">Configured</span></td>
                </tr>
                <tr>
                    <td><strong>Parallel Creative Research</strong></td>
                    <td>Cinematography & Color Science</td>
                    <td><span class="status-pill pill-blue">Active</span></td>
                </tr>
                <tr>
                    <td><strong>Grafana Observability</strong></td>
                    <td><code>{{ grafana_url }}</code></td>
                    <td><span class="status-pill pill-active">Port 3000</span></td>
                </tr>
                <tr>
                    <td><strong>ZeroConf / Bonjour</strong></td>
                    <td><code>_metalcraft._tcp</code></td>
                    <td><span class="status-pill pill-active">Broadcasting</span></td>
                </tr>
            </table>
        </div>

        <div class="card">
            <h2>📡 Available REST API Routes</h2>
            <table>
                <tr>
                    <th>Method</th>
                    <th>Endpoint</th>
                    <th>Description</th>
                </tr>
                <tr>
                    <td><code>GET</code></td>
                    <td><a href="/health">/health</a></td>
                    <td>Server health check and latency probing</td>
                </tr>
                <tr>
                    <td><code>POST</code></td>
                    <td><code>/api/v1/agent/create</code></td>
                    <td>Creative Director prompt analysis & EditPlan synthesis</td>
                </tr>
                <tr>
                    <td><code>POST</code></td>
                    <td><code>/api/v1/telemetry</code></td>
                    <td>MetalCraft GPU execution & latency event ingestion</td>
                </tr>
                <tr>
                    <td><code>GET</code></td>
                    <td><a href="/api/v1/observability">/api/v1/observability</a></td>
                    <td>Live performance & GPU frame-budget metrics</td>
                </tr>
            </table>
        </div>
    </div>
</body>
</html>
"""

@app.route("/", methods=["GET"])
def home():
    return render_template_string(
        HOME_HTML,
        port=PORT,
        hostname=socket.gethostname(),
        grafana_url=GRAFANA_URL
    ), 200

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

@app.route("/api/v1/diagnostics/test_all", methods=["GET", "POST"])
def test_all_integrations():
    """Runs a complete end-to-end runtime diagnostic of all connected services."""
    client_ip = request.remote_addr
    logger.info(f"[AgentConnection] Complete integration diagnostics triggered by {client_ip}")
    
    # 1. Local Agent Health
    agent_health = {
        "status": "PASS",
        "service": "MetalCraft Local Agent",
        "version": "1.0.0",
        "hostname": socket.gethostname(),
        "port": PORT
    }
    
    # 2. Gemini Configuration Check
    gemini_status = {
        "status": "PASS" if bool(GEMINI_API_KEY) else "MISSING",
        "configured": bool(GEMINI_API_KEY),
        "model": "gemini-2.5-flash",
        "serverSideOnly": True
    }
    
    # 3. Parallel API Runtime Check
    from agent.tools import parallel_client
    parallel_status = parallel_client.test_connection()
    
    # 4. Grafana Health & Service Account
    grafana_status = grafana_client.get_grafana_health()
    
    # 5. Grafana MCP Server
    from mcp.grafana_mcp_server import GrafanaMCPServer
    mcp = GrafanaMCPServer()
    mcp_resp = mcp.handle_request({
        "jsonrpc": "2.0",
        "id": "diag-1",
        "method": "tools/call",
        "params": {"name": "grafana_get_health"}
    })
    mcp_status = {
        "status": "PASS" if "result" in mcp_resp else "FAIL",
        "server": "metalcraft-grafana-mcp",
        "protocol": "JSON-RPC 2.0 (2024-11-05)"
    }
    
    # 6. Telemetry Ingestion Buffer
    telemetry_summary = grafana_client.query_observability("latency")
    
    overall_pass = (
        agent_health["status"] == "PASS" and
        gemini_status["status"] == "PASS" and
        parallel_status["status"] == "PASS" and
        grafana_status["status"] == "PASS"
    )
    
    return jsonify({
        "timestamp": int(time.time()),
        "overallStatus": "PASS" if overall_pass else "WARN",
        "agent": agent_health,
        "gemini": gemini_status,
        "parallel": parallel_status,
        "grafana": grafana_status,
        "grafanaMCP": mcp_status,
        "telemetry": telemetry_summary
    }), 200

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
