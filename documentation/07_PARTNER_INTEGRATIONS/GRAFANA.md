# Grafana Integration Architecture

## Role

Grafana is the **primary partner** for the Agentic Cinema hackathon. It serves as the production observability layer, providing the agent with real-time insight into MetalCraft's processing performance.

## Why Grafana Is Primary

1. **Enables the agentic feedback loop**: Agent observes processing metrics → reasons about performance → adapts EditPlan
2. **Real production observability**: Not simulated — actual GPU timing, error rates, and throughput data
3. **MCP integration**: Grafana provides MCP tools that the ADK agent can invoke directly
4. **Visual dashboards**: Judges can see live dashboards during demo

## Architecture

```
MetalCraft (iOS)
    │
    │ TelemetryService.emit(event)
    │
    ▼
Cloud Run Telemetry Endpoint
    │
    │ POST /api/v1/telemetry
    │
    ▼
Grafana Cloud (Data Source)
    │
    │ Stores: processing events, timing, errors
    │
    ▼
Grafana MCP Server
    │
    │ Agent tool: query_observability
    │
    ▼
ADK Agent (Gemini)
    │
    │ Reasons about: "blur took 800ms, too slow"
    │
    ▼
Revised EditPlan
```

## Telemetry Event Schema

```json
{
  "eventType": "processing_complete | processing_error | export_complete | frame_processed",
  "timestamp": "ISO-8601",
  "sessionId": "uuid",
  "requestId": "uuid (links to agent request)",
  "operation": "gaussianBlur",
  "processingTimeMs": 45.2,
  "gpuTimeMs": 12.8,
  "passCount": 2,
  "resolution": "4032x3024",
  "mediaType": "image",
  "errorMessage": null,
  "texturePoolSize": 4,
  "memoryUsageMB": 128.5
}
```

## Grafana Dashboard Panels

1. **Processing Latency** — Time series of processingTimeMs per operation
2. **GPU Time** — Time series of gpuTimeMs
3. **Error Rate** — Count of processing_error events
4. **Operations Breakdown** — Pie chart of operation types processed
5. **Throughput** — Frames or images processed per minute
6. **Agent Activity** — Agent request count, average response time
7. **Memory Usage** — Texture pool size and memory pressure

## MCP Tool: query_observability

```python
@tool
def query_observability(query_type: str, time_range: str = "5m") -> dict:
    """Query Grafana for processing telemetry.
    
    Args:
        query_type: One of "latency", "errors", "throughput", "operations", "memory"
        time_range: Time range like "5m", "1h", "24h"
    
    Returns:
        dict with query results from Grafana
    """
```

## Security

- Grafana API key stored in Secret Manager (NEVER in iOS app)
- Telemetry contains NO user media content — only metadata and timing
- Session IDs are ephemeral, no PII
- Data retention: 30 days (configurable)
