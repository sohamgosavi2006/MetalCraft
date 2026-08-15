# Master Implementation Plan

> **This is the single document Gemini must read first before implementing any phase.**
> It is the source of truth for the entire implementation roadmap.

---

## Project Purpose

Transform MetalCraft from a standalone GPU-accelerated media editor into an Agentic Media-Production Platform where Gemini acts as a Creative Director, Parallel provides external creative research, Grafana provides production observability, and Apple Metal performs the actual GPU processing.

## Existing Architecture Summary

MetalCraft is a fully functional iOS application with:
- **10 Metal GPU compute shaders** (adjustments, grayscale, invert, gaussian blur, sharpen, sobel edge, pixelate, ripple, swirl, convolution)
- **MetalContext** → **MetalProcessor** → **ProcessingPipeline** architecture
- **Image editing**: import, process, preview, compare, export, Photos save
- **Video editing**: import, playback, GPU frame processing, timeline, export, Photos save
- **Project management**: multi-image + multi-video projects with persistence
- **Analytics**: GPU timing, benchmarks, histograms, processing history
- **13 passing unit tests**

See: [01_EXISTING_ARCHITECTURE/CURRENT_ARCHITECTURE.md](../01_EXISTING_ARCHITECTURE/CURRENT_ARCHITECTURE.md)

## Non-Negotiable Constraints

1. **DO NOT** remove, replace, or rewrite existing Metal shaders, MetalContext, MetalProcessor, TexturePool, ProcessingPipeline, or any existing service
2. **DO NOT** modify existing image/video editing behavior unless a specific change is technically necessary for integration
3. **DO NOT** put API keys, Grafana keys, Parallel keys, or Google Cloud credentials inside the iOS application or public repository
4. **DO NOT** allow Gemini to directly access MTLDevice, MTLTexture, MTLCommandQueue, or execute arbitrary Swift/Metal code
5. **DO NOT** upload full-resolution images/videos to cloud without explicit user consent
6. **ALL** AI-to-editor communication must flow through the validated EditPlan schema
7. **ALL** existing unit tests must continue passing after every phase

## Target Architecture

See: [02_TARGET_ARCHITECTURE/TARGET_ARCHITECTURE.md](../02_TARGET_ARCHITECTURE/TARGET_ARCHITECTURE.md)

---

## Phase Ordering & Dependencies

```
PHASE 0: Repository Audit
    │
    ▼
PHASE 1: EditPlan Schema + Models
    │
    ▼
PHASE 2: EditPlan Executor (iOS)
    │
    ▼
PHASE 3: Telemetry Service (iOS)
    │
    ▼
PHASE 4: Agent Service (iOS networking)
    │
    ▼
PHASE 5: AI Create UI (SwiftUI)
    │   (requires Phase 2, 4)
    ▼
PHASE 6: Google Cloud Foundation
    │   (Cloud Run, Secret Manager, IAM)
    ▼
PHASE 7: ADK Agent (Python)
    │   (requires Phase 1, 6)
    ▼
PHASE 8: Gemini Tool Definitions
    │   (requires Phase 7)
    ▼
PHASE 9: Grafana MCP Integration
    │   (requires Phase 3, 8)
    ▼
PHASE 10: Parallel MCP Integration
    │   (requires Phase 8)
    ▼
PHASE 11: Agent Feedback Loop
    │   (requires Phase 9, 10)
    ▼
PHASE 12: Security Hardening
    │
    ▼
PHASE 13: Testing & Regression
    │
    ▼
PHASE 14: Deployment
    │
    ▼
PHASE 15: Hackathon Demo & Submission
```

---

## Phase Details

### PHASE 0 — Repository Audit & Baseline

**Objective**: Verify the existing codebase matches this documentation. Establish baseline.

**Tasks**:
- [ ] Clone repository and verify file structure matches `CURRENT_ARCHITECTURE.md`
- [ ] Run `xcodebuild test` and confirm all 13 tests pass
- [ ] Build and deploy to physical device, confirm app launches
- [ ] Document any discrepancies between this documentation and actual code

**Files**: DO NOT TOUCH any production files. Read-only audit.

**Acceptance Criteria**: All tests pass. App launches. Documentation matches reality.

---

### PHASE 1 — EditPlan Schema + Models (iOS)

**Objective**: Define the EditPlan Swift models and JSON schema.

**Prerequisites**: Phase 0

**New Files**:
- `MetalCraft/Models/EditPlan.swift` — EditPlan, EditPlanOperation, EditPlanAdjustments, EditPlanOutput structs (all Codable)
- `MetalCraft/Models/AgentState.swift` — AgentState enum, AgentMessage model

**Existing Files Modified**:
- NONE

**Tasks**:
- [ ] Create `EditPlan` struct matching schema in [06_AGENTIC_AI/EDIT_PLAN.md](../06_AGENTIC_AI/EDIT_PLAN.md)
- [ ] Create `EditPlanOperation` struct with `type: String` and `parameters: [String: AnyCodableValue]`
- [ ] Create `EditPlanAdjustments` struct mapping to AdjustmentParams
- [ ] Create `EditPlanOutput` struct (format, quality)
- [ ] Create `AgentState` enum (idle, analyzing, researching, planning, validating, waitingForApproval, executing, observing, evaluating, revising, completed, failed, cancelled, timeout)
- [ ] Create `AgentMessage` struct for agent communication display
- [ ] Add unit tests for EditPlan JSON encoding/decoding round-trips

**Acceptance Criteria**: EditPlan can be serialized to/from JSON. All existing tests still pass.

---

### PHASE 2 — EditPlan Executor (iOS)

**Objective**: Translate validated EditPlan JSON into ProcessingPipeline + AdjustmentParams.

**Prerequisites**: Phase 1

**New Files**:
- `MetalCraft/Services/EditPlanExecutor.swift`

**Existing Files Modified**:
- `MetalCraft/App/AppState.swift` — Add `func applyEditPlan(_ plan: EditPlan)` method that calls EditPlanExecutor and updates pipeline/adjustments

**Tasks**:
- [ ] Create `EditPlanExecutor` service
- [ ] Implement `func execute(_ plan: EditPlan) throws -> (ProcessingPipeline, AdjustmentParams)`
- [ ] Map each EditPlan operation type string to ProcessingOperation enum case
- [ ] Validate parameter ranges (reject out-of-bounds values)
- [ ] Add `applyEditPlan()` to AppState that calls executor and triggers `reprocessImage()`
- [ ] Unit tests: valid plan → correct pipeline, invalid plan → thrown error, empty plan → empty pipeline

**Acceptance Criteria**: A valid EditPlan JSON produces the correct ProcessingPipeline. Invalid plans throw descriptive errors. All existing tests pass.

---

### PHASE 3 — Telemetry Service (iOS)

**Objective**: Emit processing telemetry from MetalCraft that can be sent to Grafana.

**Prerequisites**: Phase 0

**New Files**:
- `MetalCraft/Services/TelemetryService.swift`

**Existing Files Modified**:
- `MetalCraft/App/AppState.swift` — Call `telemetryService.emit()` after processing completes

**Tasks**:
- [ ] Create `TelemetryService` with `func emit(event: TelemetryEvent)`
- [ ] Define `TelemetryEvent` struct (eventType, timestamp, processingTimeMs, gpuTimeMs, passCount, resolution, operationName, errorMessage)
- [ ] Buffer events locally (in-memory array, max 100)
- [ ] Add `func flush() -> [TelemetryEvent]` to retrieve buffered events for sending to cloud
- [ ] Emit events after each `reprocessImage()` and `videoPlayerController` frame processing
- [ ] Unit tests for event buffering and flush

**Acceptance Criteria**: Processing operations emit telemetry events. Events can be serialized to JSON. Existing tests pass.

---

### PHASE 4 — Agent Service (iOS networking)

**Objective**: iOS service for communicating with the Cloud Run agent endpoint.

**Prerequisites**: Phase 1

**New Files**:
- `MetalCraft/Services/AgentService.swift`

**Existing Files Modified**:
- `MetalCraft/App/AppState.swift` — Add `agentService` property, `agentState`, `agentMessages`

**Tasks**:
- [ ] Create `AgentService` with `func sendCreativeRequest(prompt: String, mediaMetadata: MediaMetadata, thumbnail: Data?) async throws -> AgentResponse`
- [ ] Define `MediaMetadata` struct (type, width, height, format, fps, duration, histogramSummary)
- [ ] Define `AgentResponse` struct (requestId, agentState, editPlan, reasoning, researchContext, confidence)
- [ ] Implement HTTPS POST to configurable endpoint URL
- [ ] Handle: timeout (30s), network errors, malformed responses
- [ ] Add `agentState` and `agentMessages` to AppState for UI display
- [ ] Store endpoint URL in app configuration (NOT hardcoded)

**Acceptance Criteria**: AgentService can send requests and decode responses. Network errors are handled gracefully. Existing tests pass.

---

### PHASE 5 — AI Create UI (SwiftUI)

**Objective**: Replace the "Coming Soon" placeholder with the agentic creative interface.

**Prerequisites**: Phase 2, Phase 4

**Existing Files Modified**:
- `MetalCraft/Views/AICreate/AICreateView.swift` — Complete rewrite of placeholder

**New Files**:
- `MetalCraft/Views/AICreate/AgentMessageBubble.swift`
- `MetalCraft/Views/AICreate/EditPlanPreviewView.swift`

**Tasks**:
- [ ] Replace AICreateView with: prompt input field, send button, agent state indicator, message history, EditPlan preview card, approve/reject buttons
- [ ] Show agent state transitions (ANALYZING → RESEARCHING → PLANNING → etc.)
- [ ] Display EditPlan as a visual card showing operations and adjustments
- [ ] "Apply" button that calls `appState.applyEditPlan(plan)` and switches to Editor tab
- [ ] "Revise" button that sends revision request
- [ ] Display Parallel research context when available
- [ ] Display agent reasoning

**Acceptance Criteria**: User can type a prompt, see agent reasoning, preview EditPlan, approve and see it applied to the editor. Existing tests pass.

---

### PHASE 6 — Google Cloud Foundation

**Objective**: Set up Google Cloud infrastructure for the agent.

**Prerequisites**: Phase 0

**New Files** (cloud/ directory in new hackathon repo):
- `cloud/Dockerfile`
- `cloud/requirements.txt`
- `cloud/main.py` (Flask/FastAPI entry point)
- `cloud/cloudbuild.yaml` or deployment scripts

**Tasks**:
- [ ] Create Google Cloud project
- [ ] Enable required APIs (Cloud Run, Secret Manager, IAM, Vertex AI)
- [ ] Create Secret Manager secrets for: Gemini API key, Grafana API key, Parallel API key
- [ ] Set up IAM service account with minimal permissions
- [ ] Create Cloud Run service skeleton (Python + Flask/FastAPI)
- [ ] Deploy "hello world" endpoint and verify connectivity from iOS

**Acceptance Criteria**: Cloud Run endpoint is reachable. Secrets are stored securely. IAM is configured.

---

### PHASE 7 — ADK Agent (Python)

**Objective**: Implement the Gemini agent using Google Cloud Agent Development Kit.

**Prerequisites**: Phase 1 (EditPlan schema), Phase 6

**New Files**:
- `cloud/agent/agent.py` — ADK agent definition
- `cloud/agent/prompts.py` — System prompts
- `cloud/agent/tools.py` — Tool function definitions
- `cloud/agent/schemas.py` — Tool input/output JSON schemas

**Tasks**:
- [ ] Define agent with system prompt establishing Creative Director role
- [ ] Configure Gemini model (gemini-2.0-flash)
- [ ] Define tool declarations matching [06_AGENTIC_AI/AGENT_ARCHITECTURE.md](../06_AGENTIC_AI/AGENT_ARCHITECTURE.md)
- [ ] Implement `create_edit_plan` tool that generates EditPlan JSON
- [ ] Implement `validate_edit_plan` tool
- [ ] Implement `analyze_media` tool
- [ ] Wire agent to Flask/FastAPI endpoint
- [ ] Test with curl/Postman

**Acceptance Criteria**: Agent receives a prompt and media metadata, returns a valid EditPlan JSON.

---

### PHASE 8 — Gemini Tool Definitions

**Objective**: Implement all agent tools with proper schemas, error handling, and safety.

**Prerequisites**: Phase 7

**Tasks**:
- [ ] Implement all 10 tools from the tool table in AGENT_ARCHITECTURE.md
- [ ] Add parameter validation for each tool
- [ ] Add error handling (tool failure → agent receives error message, not crash)
- [ ] Add loop bounds (max 3 revisions)
- [ ] Add timeout handling (60s max agent session)
- [ ] Test each tool individually

**Acceptance Criteria**: Each tool produces valid output. Error cases are handled. Loop bounds enforced.

---

### PHASE 9 — Grafana MCP Integration

**Objective**: Connect the agent to Grafana via MCP for processing observability.

**Prerequisites**: Phase 3 (TelemetryService), Phase 8

**New Files**:
- `cloud/mcp/grafana_client.py` — Grafana MCP client
- `cloud/agent/tools_grafana.py` — `query_observability` tool implementation

**Tasks**:
- [ ] Set up Grafana Cloud instance (or local Grafana)
- [ ] Configure data source for MetalCraft telemetry
- [ ] Create Grafana dashboard: processing latency, error rate, throughput, operation breakdown
- [ ] Implement `query_observability` tool that queries Grafana MCP
- [ ] Connect TelemetryService (iOS) → Grafana endpoint
- [ ] Verify agent can query telemetry and reason about it

**Acceptance Criteria**: Processing telemetry appears in Grafana. Agent can query and interpret telemetry data.

---

### PHASE 10 — Parallel MCP Integration

**Objective**: Connect the agent to Parallel via MCP for creative research.

**Prerequisites**: Phase 8

**New Files**:
- `cloud/mcp/parallel_client.py` — Parallel MCP client
- `cloud/agent/tools_parallel.py` — `research_creative_context` tool implementation

**Tasks**:
- [ ] Configure Parallel MCP access (API key in Secret Manager)
- [ ] Implement `research_creative_context` tool
- [ ] Define input schema (query, topic, maxResults)
- [ ] Define output schema (results with citations/references)
- [ ] Add prompt injection protection (sanitize user input before passing to Parallel)
- [ ] Agent decides WHEN to call Parallel (not every request)
- [ ] Test with creative research queries

**Acceptance Criteria**: Agent can optionally call Parallel for creative references. Results are grounded with citations.

---

### PHASE 11 — Agent Feedback Loop

**Objective**: Implement the full OBSERVE → REASON → ACT → EVALUATE → REVISE loop.

**Prerequisites**: Phase 9, Phase 10

**Tasks**:
- [ ] After EditPlan execution, agent queries Grafana for processing metrics
- [ ] Agent evaluates: was processing time acceptable? any errors?
- [ ] If revision needed: agent generates revised EditPlan
- [ ] MetalCraft re-processes with revised plan
- [ ] Loop bounded to 3 iterations maximum
- [ ] Show iteration progress in AI Create UI

**Acceptance Criteria**: Agent can observe, evaluate, and revise. Loop terminates correctly. User sees the iterative process.

---

### PHASE 12 — Security Hardening

**Prerequisites**: Phase 11

**Tasks**:
- [ ] Verify no secrets in iOS app or public repo
- [ ] Verify Secret Manager usage for all API keys
- [ ] Add input validation on all API endpoints
- [ ] Add rate limiting on Cloud Run
- [ ] Add EditPlan schema validation (reject unknown fields)
- [ ] Add prompt injection protection
- [ ] Verify HTTPS-only communication
- [ ] Review IAM permissions (least privilege)

---

### PHASE 13 — Testing & Regression

**Prerequisites**: Phase 12

**Tasks**:
- [ ] Run all existing 13 unit tests — must pass
- [ ] Add unit tests for EditPlan serialization
- [ ] Add unit tests for EditPlanExecutor
- [ ] Add unit tests for TelemetryService
- [ ] Add integration test: prompt → EditPlan → pipeline → processing
- [ ] Add agent test: prompt → valid EditPlan JSON
- [ ] Manual test: import image, apply AI edit, compare, export
- [ ] Manual test: import video, apply AI edit, play, export
- [ ] Regression: verify all existing editor controls still work

---

### PHASE 14 — Deployment

**Tasks**:
- [ ] Deploy final Cloud Run agent
- [ ] Verify Grafana dashboard
- [ ] Build iOS app with release configuration
- [ ] Deploy to physical device
- [ ] End-to-end test on real device

---

### PHASE 15 — Hackathon Demo & Submission

**Tasks**:
- [ ] Record demo video following script in ELIGIBILITY_RISK.md
- [ ] Create Devpost submission
- [ ] Link new hackathon repository
- [ ] Disclose prior art (MetalCraft Metal engine)
- [ ] Submit before deadline

---

## Critical Contracts

| Contract | Document |
|----------|----------|
| EditPlan JSON Schema | [06_AGENTIC_AI/EDIT_PLAN.md](../06_AGENTIC_AI/EDIT_PLAN.md) |
| Agent Tool Schemas | [06_AGENTIC_AI/AGENT_ARCHITECTURE.md](../06_AGENTIC_AI/AGENT_ARCHITECTURE.md) |
| iOS ↔ Cloud API | [02_TARGET_ARCHITECTURE/TARGET_ARCHITECTURE.md](../02_TARGET_ARCHITECTURE/TARGET_ARCHITECTURE.md) |
| Media Data Boundary | [02_TARGET_ARCHITECTURE/TARGET_ARCHITECTURE.md](../02_TARGET_ARCHITECTURE/TARGET_ARCHITECTURE.md) |

## Definition of Done (per phase)

- [ ] All specified tasks completed
- [ ] New code compiles without errors
- [ ] All existing unit tests pass
- [ ] New unit tests written and passing
- [ ] No existing functionality broken
- [ ] Files changed are documented
- [ ] Deviations from plan are explained
