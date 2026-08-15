# Target Architecture

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        iOS APPLICATION                       │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Editor   │  │AI Create │  │Analytics │  │ Projects │   │
│  │  (SwiftUI)│  │(SwiftUI) │  │(SwiftUI) │  │(SwiftUI) │   │
│  └─────┬────┘  └─────┬────┘  └────┬─────┘  └──────────┘   │
│        │              │            │                         │
│        ▼              ▼            ▼                         │
│  ┌─────────────────────────────────────────────────┐        │
│  │              AppState (@Observable)               │        │
│  │  ┌──────────┐ ┌────────────┐ ┌────────────────┐ │        │
│  │  │Pipeline  │ │AgentState  │ │TelemetryEmitter│ │        │
│  │  │Adjustments│ │EditPlan   │ │                │ │        │
│  │  └──────────┘ └────────────┘ └────────────────┘ │        │
│  └────────────────────┬────────────────────────────┘        │
│                       │                                      │
│        ┌──────────────┼──────────────┐                      │
│        ▼              ▼              ▼                      │
│  ┌──────────┐  ┌────────────┐  ┌──────────────┐            │
│  │EditPlan  │  │  Metal     │  │  Telemetry   │            │
│  │Executor  │  │  Processor │  │  Service     │            │
│  │          │  │  (GPU)     │  │              │            │
│  └────┬─────┘  └─────┬──────┘  └──────┬───────┘            │
│       │               │                │                     │
│       ▼               ▼                │                     │
│  ProcessingPipeline  MTLTexture        │                     │
│       │               │                │                     │
│       └───────┬───────┘                │                     │
│               ▼                        │                     │
│         Metal GPU Shaders              │                     │
│               │                        │                     │
│               ▼                        │                     │
│         Image / Video                  │                     │
│                                        │                     │
│  ┌─────────────────────────────────────┼─────────────────┐  │
│  │         AgentService (HTTPS)        │                 │  │
│  └─────────────────┬───────────────────┘                 │  │
└────────────────────┼─────────────────────────────────────┘  │
                     │                                         │
                     ▼                                         │
┌────────────────────────────────────────────────────────────┐
│                    GOOGLE CLOUD                             │
│                                                             │
│  ┌─────────────────────────────────────────────┐           │
│  │        Cloud Run (Agent Endpoint)            │           │
│  │  ┌───────────────────────────────────┐      │           │
│  │  │  ADK Agent (Python)               │      │           │
│  │  │  ├── Gemini (reasoning engine)    │      │           │
│  │  │  ├── Tool: analyze_media          │      │           │
│  │  │  ├── Tool: create_edit_plan       │      │           │
│  │  │  ├── Tool: research_creative_ctx  │──────┼──► Parallel MCP
│  │  │  ├── Tool: query_observability    │──────┼──► Grafana MCP
│  │  │  ├── Tool: validate_edit_plan     │      │           │
│  │  │  └── Tool: review_result         │      │           │
│  │  └───────────────────────────────────┘      │           │
│  └─────────────────────────────────────────────┘           │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │Secret Manager│  │     IAM      │                        │
│  └──────────────┘  └──────────────┘                        │
└────────────────────────────────────────────────────────────┘
```

## Data Flow

```
User Intent (text prompt in AI Create)
    │
    ▼
AgentService.sendRequest(prompt, mediaMetadata)
    │  HTTPS POST to Cloud Run
    ▼
ADK Agent receives request
    │
    ├── Gemini analyzes intent
    ├── (optional) Tool: research_creative_context → Parallel MCP
    ├── (optional) Tool: query_observability → Grafana MCP
    ├── Tool: create_edit_plan → structured EditPlan JSON
    ├── Tool: validate_edit_plan → schema + capability validation
    │
    ▼
EditPlan JSON response → iOS
    │
    ▼
EditPlanExecutor.execute(editPlan)
    │
    ├── Validates against ProcessingOperation capabilities
    ├── Translates operations[] → PipelineNode[]
    ├── Translates adjustments → AdjustmentParams
    ├── Sets ProcessingPipeline on AppState
    │
    ▼
AppState.reprocessImage() / VideoPlayerController.updatePipeline()
    │
    ▼
MetalProcessor dispatches GPU shaders
    │
    ▼
TelemetryService emits processing metrics
    │  → Grafana (for agent observability)
    ▼
Result texture → display
    │
    ▼
(optional) Agent evaluates result via Grafana telemetry
    │
    ▼
(optional) Agent revises EditPlan
```

## Media Data Boundary

| Data | Location | Rationale |
|------|----------|-----------|
| Original images/videos | LOCAL ONLY | Privacy, bandwidth, cost |
| Processed textures | LOCAL ONLY | GPU memory, no cloud need |
| Media metadata (resolution, FPS, duration) | CLOUD (with request) | Agent needs context |
| Thumbnail (low-res, <100KB) | CLOUD (optional, user-consented) | Agent visual analysis |
| Histogram summary | CLOUD (optional) | Agent color analysis |
| User prompt text | CLOUD | Agent reasoning |
| EditPlan JSON | CLOUD → LOCAL | The AI-to-editor contract |
| Processing telemetry | CLOUD (Grafana) | Agent observability |
| API keys / secrets | CLOUD ONLY (Secret Manager) | Security |

## Agent ↔ MetalCraft Boundary

**Gemini decides WHAT should happen. MetalCraft decides HOW it is executed.**

```
ALLOWED for Gemini:
  ✅ Specify operation type (e.g., "gaussianBlur")
  ✅ Specify parameters (e.g., sigma: 2.5)
  ✅ Specify operation ordering
  ✅ Specify output format preferences
  ✅ Request media analysis results
  ✅ Query Grafana for processing metrics

NOT ALLOWED for Gemini:
  ❌ Direct MTLDevice access
  ❌ Direct MTLTexture manipulation
  ❌ Direct MTLCommandQueue access
  ❌ Metal shader source code generation
  ❌ Arbitrary Swift code execution
  ❌ File system access
  ❌ Camera/microphone access
```
