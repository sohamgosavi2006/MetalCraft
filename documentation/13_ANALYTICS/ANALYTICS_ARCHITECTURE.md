# Analytics & Telemetry Architecture

## Existing Analytics (In-App)

MetalCraft already has a comprehensive analytics system:

| Component | Status | Purpose |
|-----------|--------|---------|
| PerformanceMetrics | ✅ | GPU timing per operation |
| BenchmarkEngine | ✅ | CPU vs GPU comparative benchmarks |
| HistogramCalculator | ✅ | RGBA histogram from MTLTexture |
| ProcessingHistory | ✅ | Log of processing events |
| ExportHistory | ✅ | Log of export events |
| NodeRuntimeState | ✅ | Per-pipeline-node execution state |
| MemoryResourceMetrics | ✅ | Texture pool and memory tracking |

## New: Telemetry for Agent Observability (Phase 3)

### TelemetryService

The TelemetryService bridges in-app analytics with external observability (Grafana).

**Flow**:
```
AppState.reprocessImage()
    │
    ├── MetalProcessor processes pipeline
    │
    ├── Performance metrics collected
    │
    ▼
TelemetryService.emit(TelemetryEvent)
    │
    ├── Buffer event locally (in-memory, max 100)
    │
    ├── (Background) Flush to Cloud Run /api/v1/telemetry
    │
    ▼
Cloud Run → Grafana Cloud (data source)
    │
    ▼
Agent queries via Grafana MCP
```

### What Gets Telemetered

| Event | When | Data |
|-------|------|------|
| `processing_complete` | After successful pipeline run | Operation name, timing, pass count |
| `processing_error` | After failed pipeline run | Error message, operation that failed |
| `frame_processed` | After each video frame GPU pass | Frame index, timing |
| `export_complete` | After successful export | Format, resolution, file size |
| `agent_request` | After agent request received | Prompt length, media type |
| `agent_response` | After agent response sent | EditPlan operation count, confidence |

### What NEVER Gets Telemetered

- ❌ User images or video content
- ❌ User names, device identifiers, or PII
- ❌ API keys or credentials
- ❌ File paths or system information
