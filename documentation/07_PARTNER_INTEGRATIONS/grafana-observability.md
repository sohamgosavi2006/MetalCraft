# MetalCraft — Grafana Observability & Telemetry Pipeline

## 1. Overview
MetalCraft uses Grafana Cloud for live performance telemetry, monitoring GPU frame render times, pass counts, memory pressure, and agent planning latency.

---

## 2. Server-Side Telemetry Ingestion Flow
1. iOS emits telemetry events locally and flushes them to `POST /api/v1/telemetry`.
2. The Render backend sanitizes events (strips any accidentally included tokens or secrets).
3. Events are saved into the SQLite persistent store and buffered in an in-memory rolling buffer for instant Web UI queries.
4. When `GRAFANA_URL` and `GRAFANA_TOKEN` are configured, events are pushed asynchronously to Grafana Cloud / Loki.

---

## 3. Real Telemetry Events Monitored
- `VIDEO_RENDER_STARTED`
- `VIDEO_RENDER_COMPLETED` (tracks `gpuTimeMs` and `processingTimeMs`)
- `VIDEO_ARTIFACT_CREATED`
- `VIDEO_VALIDATION_COMPLETED`
- `VIDEO_PREVIEW_READY`
- `VIDEO_SHARED`
- `VIDEO_SAVED_TO_PHOTOS`
- `VIDEO_ADDED_TO_PROJECT`

Every event contains:
- `generationId`: Trace correlation ID.
- `sessionId`: Unique device or client session.
- `timestamp`: UTC ISO-8601 timestamp.
- `gpuTimeMs`: Measured frame render time on Apple Silicon GPU (target < 33.3ms for 30 FPS).
