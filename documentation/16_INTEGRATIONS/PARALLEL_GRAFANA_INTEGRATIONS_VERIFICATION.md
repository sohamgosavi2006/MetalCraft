# MetalCraft — Parallel & Grafana Integrations Verification & Architecture Guide

## 1. Overview

This document specifies the end-to-end architecture, runtime verification, security guarantees, and telemetry pipelines connecting **MetalCraft iOS**, the **Local Mac Agent Backend**, **Google Gemini**, **Parallel Creative Search API**, and **Grafana 11.5 Observability**.

```
┌────────────────────────────────────────────────────────┐
│                   iPhone MetalCraft App                 │
│  - Metal GPU Image/Video Engine (Metal 3)              │
│  - AI Create Studio (Multi-Scene Video Composition)     │
│  - Analytics Observability Center (8 Systematic Tabs)  │
└──────────────────────────┬─────────────────────────────┘
                           │ Local Network (HTTP / Bonjour)
                           ▼
┌────────────────────────────────────────────────────────┐
│             Local Mac Agent Backend (Port 8080)        │
│  - Zero secrets exposed to iOS                         │
│  - Creative Director & Tool Calling Engine             │
│  - Telemetry Ingestion & Metrics Aggregator            │
└───────┬──────────────────┬──────────────────────┬──────┘
        │                  │                      │
        ▼                  ▼                      ▼
┌──────────────┐   ┌──────────────┐   ┌───────────────────────────┐
│ Gemini 2.5   │   │ Parallel API │   │ Local Grafana (Port 3000) │
│ Flash Model  │   │ Search API   │   │ - Service Account Auth    │
│ - Reasoning  │   │ - Research   │   │ - Prometheus / Telemetry  │
│ - EditPlans  │   │ - References │   │ - Grafana MCP (JSON-RPC)  │
└──────────────┘   └──────────────┘   └───────────────────────────┘
```

---

## 2. Parallel Integration

### Role in MetalCraft
Parallel is dedicated exclusively to **CREATIVE RESEARCH** (e.g. cinematography references, color theory, split-toning techniques, and aesthetic recommendations). It is NOT used for image rendering, Metal shaders, or authentication.

### Security Architecture
- `PARALLEL_API_KEY` is loaded strictly server-side by the Mac Agent backend via `.env`.
- It is NEVER present in Swift source code, `Info.plist`, `UserDefaults`, or network packets sent to iOS.

### Verified Runtime Schema
- Endpoint: `POST https://api.parallel.ai/v1/search`
- Headers:
  - `Authorization: Bearer <PARALLEL_API_KEY>`
  - `Content-Type: application/json`
- Request Payload:
  ```json
  {
    "search_queries": ["cinematic lighting color grading"]
  }
  ```
- Response Payload (HTTP 200 OK):
  ```json
  {
    "search_id": "search_9ef3bce190ad00520cf50ff9ab9af6db",
    "results": [
      {
        "title": "The Art of Color Grading for Cinematic Lighting",
        "url": "https://www.numberanalytics.com/blog/the-art-of-color-grading-for-cinematic-lighting",
        "publish_date": "2026-06-26",
        "excerpts": ["Color theory is the foundation of color grading..."]
      }
    ]
  }
  ```

### Usage Dashboard Notes
- Parallel Platform Dashboard: `Settings` → `Usage`.
- If "No usage available" is shown, verify:
  1. Selected Date Range includes the current UTC date.
  2. Product filter is set to "All" or "Search API".
  3. Real API requests send the correct `search_queries` body format.

---

## 3. Grafana 11.5 Local Observability & MCP Server

### Local Architecture
- Endpoint: `http://localhost:3000`
- Service Account: Configured with Admin/Editor permissions (`Main Org.`).
- Dashboard: `metalcraft-observability` (`/d/metalcraft-observability/a3fc285`)

### Grafana Model Context Protocol (MCP) Server
- Implemented in `agent_backend/mcp/grafana_mcp_server.py`.
- Protocol: JSON-RPC 2.0 (2024-11-05 standard).
- Supported Tools:
  1. `grafana_get_health`: Returns Grafana database health, version, and server status.
  2. `grafana_query_observability`: Retrieves GPU frame latency, pass count, throughput, and error rates.

---

## 4. Diagnostics & Testing Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/health` | `GET` | Probes Mac Agent backend liveness and network latency. |
| `/api/v1/diagnostics/test_all` | `GET` | Runs end-to-end checks across Agent, Gemini, Parallel, Grafana, and Telemetry. |
| `/api/v1/telemetry` | `POST` | Ingests GPU processing and export events from MetalCraft. |
| `/api/v1/observability` | `GET` | Aggregated performance metrics for agent evaluation. |

---

## 5. Security & Secret Governance

1. **Zero Secret Leakage**: No API keys or tokens exist in Git history, committed `.env` files, or iOS app bundles.
2. **Environment Template**: `.env.example` contains only placeholder keys.
3. **Fail-Safe Offline Mode**: If Parallel, Gemini, or Grafana are unreachable, MetalCraft's manual editor and GPU render engine continue operating uninterrupted.
