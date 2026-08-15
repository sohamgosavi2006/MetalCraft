# Architecture Decision Records

## ADR-001: Preserve Existing Metal Pipeline

**Context**: MetalCraft has a fully functional Metal GPU processing pipeline with 10 compute shaders, MetalContext, MetalProcessor, TexturePool, and ProcessingPipeline.

**Decision**: Preserve the entire existing Metal architecture unchanged. Extend it only through the ProcessingPipeline model — never by modifying MetalProcessor or shader code.

**Alternatives**: Rebuild Metal pipeline with new abstractions for agent control.

**Reasoning**: The existing pipeline is production-grade, tested, and performs well. Rebuilding introduces regression risk with zero functional benefit.

**Consequences**: New agent features must work within the existing pipeline's capability set.

---

## ADR-002: Unified Image/Video Processing Engine

**Context**: Images and videos need the same set of GPU effects.

**Decision**: Both image and video frames flow through the same MetalProcessor + ProcessingPipeline. Video frames are extracted as MTLTexture via VideoTextureProvider (CVMetalTextureCache) and processed identically to image textures.

**Alternatives**: Separate VideoEffectsEngine.

**Reasoning**: The existing MetalProcessor already processes MTLTextures regardless of source. No duplicate engine needed.

**Consequences**: All existing image effects automatically work on video frames.

---

## ADR-003: Gemini Outside the Metal Execution Layer

**Context**: The AI agent needs to control media processing.

**Decision**: Gemini operates exclusively through the EditPlan contract. It never directly touches MTLDevice, MTLTexture, MTLCommandQueue, or shader source code.

**Alternatives**: Let Gemini generate Metal shader code or directly invoke GPU APIs.

**Reasoning**: Safety, security, determinism. Generated shader code could crash the app, leak memory, or produce undefined behavior. The EditPlan provides a safe, validated boundary.

**Consequences**: Gemini can only use operations that exist in ProcessingOperation. New GPU effects require human implementation first.

---

## ADR-004: EditPlan as AI-to-Editor Contract

**Context**: Need a formal interface between AI reasoning and GPU execution.

**Decision**: Use a versioned JSON schema called EditPlan that maps directly to ProcessingPipeline + AdjustmentParams.

**Alternatives**: Free-form text instructions, direct function calls, code generation.

**Reasoning**: JSON is serializable, validatable, versionable, and human-readable. Direct mapping to existing ProcessingOperation cases ensures deterministic translation.

**Consequences**: EditPlan must be kept in sync with ProcessingOperation capabilities.

---

## ADR-005: Parallel for External Creative Research

**Context**: The agent may need external creative context (cinematography trends, filmmaking techniques, visual references).

**Decision**: Integrate Parallel via MCP as an optional research tool. The agent decides when research is needed — it is not called for every request.

**Alternatives**: Hardcode creative knowledge into system prompt, use web search.

**Reasoning**: Parallel provides grounded, citation-backed creative research. The agent's system prompt cannot contain all possible creative knowledge.

**Consequences**: Parallel calls add latency. Must have timeout and fallback behavior.

---

## ADR-006: Grafana for Production Observability

**Context**: The agent needs to observe actual processing performance to reason about and optimize results.

**Decision**: Use Grafana (via MCP) as the observability layer. MetalCraft emits processing telemetry, Grafana stores/visualizes it, and the agent queries Grafana to understand processing outcomes.

**Alternatives**: Log-based observability, in-app analytics only.

**Reasoning**: Grafana is the primary hackathon partner. It provides dashboards, alerting, and MCP tools that enable the agentic feedback loop.

**Consequences**: Requires telemetry emission from iOS and a Grafana Cloud instance.

---

## ADR-007: Sensitive Credentials Server-Side Only

**Context**: The system uses multiple API keys (Gemini, Grafana, Parallel).

**Decision**: All API keys and credentials are stored in Google Cloud Secret Manager and accessed only by the server-side agent. The iOS app authenticates to the Cloud Run endpoint with short-lived tokens — never with raw API keys.

**Alternatives**: Bundle API keys in iOS app, use environment variables on device.

**Reasoning**: Any key shipped in an iOS binary can be extracted. Server-side storage is the only secure approach.

**Consequences**: The iOS app cannot function offline for AI features (by design — GPU processing remains fully offline).

---

## ADR-008: Streaming Video Processing On-Device

**Context**: Video frames must be processed in real-time for preview and exported at full quality.

**Decision**: Video processing remains entirely on-device using AVFoundation + CVMetalTextureCache + MetalProcessor. Frames are never uploaded to cloud for processing.

**Alternatives**: Cloud-based video rendering.

**Reasoning**: Upload bandwidth, latency, cost, and privacy all prohibit cloud video rendering for an iOS app.

**Consequences**: Video effects are limited to what the device GPU can handle in real-time.

---

## ADR-009: Photos Framework for Library Export

**Context**: Users expect to save edited images/videos to their Camera Roll.

**Decision**: Use Apple's Photos framework for saving to the photo library. Request only necessary permissions (add-only where possible).

**Alternatives**: Files app export only.

**Reasoning**: Users expect "Save to Photos" as a standard iOS behavior.

**Consequences**: Must handle permission denied, limited access, and error states.

---

## ADR-010: Separate Permanent Media from Regenerable Cache

**Context**: Projects store original media and processed results.

**Decision**: Original media files are permanent and stored in the app's Documents directory. Processed textures, thumbnails, and display images are regenerable cache that can be recreated from originals + pipeline state.

**Alternatives**: Store all versions permanently.

**Reasoning**: Disk space efficiency. The pipeline + adjustments fully define the processed output.

**Consequences**: Opening a project requires re-processing if cache is evicted. This is already the current behavior.
