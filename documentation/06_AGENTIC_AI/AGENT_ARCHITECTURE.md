# Agent Architecture

## Agent Overview

The Gemini agent acts as a **Creative Director** — it understands user intent, analyzes media context, optionally researches creative references, generates structured EditPlans, observes processing results, and revises plans when necessary.

## Agent State Machine

```
IDLE
  │
  ▼ (user sends creative prompt)
ANALYZING
  │ (analyze media metadata, histogram, resolution)
  ▼
RESEARCHING (optional)
  │ (Parallel MCP for creative references)
  ▼
PLANNING
  │ (Gemini generates EditPlan)
  ▼
VALIDATING
  │ (validate EditPlan against schema + capabilities)
  ▼
WAITING_FOR_APPROVAL
  │ (user reviews EditPlan preview)
  ▼ (user approves)
EXECUTING
  │ (MetalCraft applies EditPlan via GPU)
  ▼
OBSERVING
  │ (Grafana telemetry: latency, errors, resource usage)
  ▼
EVALUATING
  │ (agent evaluates result quality)
  ├──► COMPLETED (result satisfactory)
  └──► REVISING (result needs improvement)
         │
         ▼
       PLANNING (generate revised EditPlan)
```

### Error States

| State | Trigger | Recovery |
|-------|---------|----------|
| FAILED | API error, GPU error, timeout | Show error, allow retry |
| CANCELLED | User cancels | Return to IDLE |
| TIMEOUT | Agent loop exceeds 3 iterations | Force COMPLETED with partial result |
| NEEDS_USER_INPUT | Ambiguous intent | Show clarification UI |

## Agent Tools

| Tool | Purpose | Input | Output | Side Effects |
|------|---------|-------|--------|-------------|
| `analyze_media` | Extract media metadata for agent context | mediaMetadata (resolution, FPS, histogram summary) | MediaAnalysis JSON | None (read-only) |
| `research_creative_context` | Query Parallel MCP for creative references | query string, topic | ResearchResult with citations | None (read-only) |
| `create_edit_plan` | Generate EditPlan from intent + context | userPrompt, mediaAnalysis, researchContext | EditPlan JSON | None |
| `validate_edit_plan` | Validate EditPlan against schema + capabilities | EditPlan JSON | ValidationResult (valid/invalid + reasons) | None |
| `execute_edit_plan` | Send validated EditPlan to MetalCraft for GPU execution | EditPlan JSON | ExecutionResult (jobId, status) | Triggers GPU processing |
| `get_processing_status` | Check current processing state | jobId | ProcessingStatus (progress, metrics) | None |
| `query_observability` | Query Grafana MCP for telemetry | query (latency, errors, throughput) | GrafanaResult | None |
| `review_result` | Evaluate processing result quality | jobId, resultMetadata | ReviewResult (quality assessment) | None |
| `revise_edit_plan` | Modify existing EditPlan based on evaluation | originalPlan, revisionReason | Revised EditPlan JSON | None |
| `export_media` | Trigger final export | format, quality | ExportResult (URL or status) | Triggers export |

## Agentic Feedback Loop

```
OBSERVE (Grafana telemetry: processing time, errors, resource usage)
    │
    ▼
REASON (Gemini evaluates: "Gaussian blur σ=50 caused 800ms latency")
    │
    ▼
ACT (Gemini revises: reduce σ to 20, or switch to box blur)
    │
    ▼
OBSERVE (Grafana: latency dropped to 200ms)
    │
    ▼
EVALUATE (Agent: "Result quality acceptable, latency within budget")
    │
    ▼
COMPLETE (Finalize result)
```

### Loop Bounds

- Maximum iterations: 3 (prevent infinite loops)
- Maximum total agent time: 60 seconds
- If TIMEOUT: present best result so far to user with explanation

## Agent Communication (iOS ↔ Cloud)

### Request Schema

```json
POST /api/v1/agent/create
Content-Type: application/json
Authorization: Bearer <short-lived-token>

{
  "requestId": "uuid",
  "prompt": "Make this look cinematic with warm tones",
  "mediaMetadata": {
    "type": "image",
    "width": 4032,
    "height": 3024,
    "format": "jpeg",
    "histogramSummary": { ... }
  },
  "thumbnailBase64": "optional-low-res-thumbnail",
  "preferences": {
    "autoApprove": false,
    "maxIterations": 3
  }
}
```

### Response Schema (streaming)

```json
{
  "requestId": "uuid",
  "agentState": "PLANNING",
  "editPlan": { ... },
  "reasoning": "I chose warm color grading because...",
  "researchContext": "Based on current cinematography trends...",
  "confidence": 0.85,
  "estimatedProcessingTimeMs": 250
}
```

## Gemini Configuration

- Model: `gemini-2.0-flash` (or latest available)
- System prompt: Defines Creative Director role, available tools, EditPlan schema, safety guidelines
- Temperature: 0.7 (creative but deterministic enough)
- Max tokens: 4096
- Tool declarations: All 10 tools with JSON schemas
