# Local Grafana Observability Setup Guide

## 1. Overview

This document details the local installation, configuration, service account security, telemetry bridge, and Model Context Protocol (MCP) server for Grafana running on macOS for MetalCraft development.

---

## 2. Environment Specifications

| Component | Specification |
|---|---|
| **Grafana Version** | 11.5.0 (Darwin ARM64 / Apple Silicon) |
| **Installation Path** | `/Users/user87/.grafana_local` |
| **Local URL** | `http://localhost:3000` |
| **Service Account** | `MetalCraft-Agent` (Role: `Editor`) |
| **Authentication** | Bearer Token stored in `.env` |
| **MCP Implementation** | `agent_backend/mcp/grafana_mcp_server.py` |
| **MCP Transport** | JSON-RPC 2.0 over `stdio` |

---

## 3. Configuration & Startup

### Configuration File (`~/.grafana_local/conf/custom.ini`)
```ini
[server]
protocol = http
http_addr = 127.0.0.1
http_port = 3000
domain = localhost
root_url = http://localhost:3000/

[paths]
data = /Users/user87/.grafana_local/data
logs = /Users/user87/.grafana_local/logs
plugins = /Users/user87/.grafana_local/plugins

[security]
admin_user = admin
admin_password = admin
```

### Starting Grafana Locally
```bash
/Users/user87/.grafana_local/bin/grafana server \
  --config /Users/user87/.grafana_local/conf/custom.ini \
  --homepath /Users/user87/.grafana_local
```

---

## 4. Telemetry Pipeline Architecture

```
MetalCraft iOS (iPhone / Simulator)
       │
       │ (HTTP POST /api/v1/telemetry)
       ▼
Local Agent Backend (Flask / Port 8080)
       │
       ├── In-Memory Circular Buffer (TelemetryStore)
       └── Grafana API Integration (Port 3000)
       ▲
       │ (JSON-RPC 2.0 stdio)
Grafana MCP Server (`grafana_mcp_server.py`)
       ▲
       │ (Tool Calls: query_observability, get_health)
Gemini Creative Director
```

### Telemetered Metrics:
- `processing_complete`: GPU execution duration (`gpuTimeMs`), frame time (`processingTimeMs`), pass count, resolution.
- `processing_error`: Shader compilation/dispatch errors, failure location.
- `agent_request` / `agent_response`: Prompt latency, plan complexity, confidence rating.

---

## 5. Security & Secret Protection
- The Grafana service account token is loaded exclusively from the local `.env` file via `config.py`.
- Secrets are never exposed to the iOS application bundle, never printed to console logs, and excluded from Git via `.gitignore`.
