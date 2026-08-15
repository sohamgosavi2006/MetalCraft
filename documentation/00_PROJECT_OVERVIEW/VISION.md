# Vision

MetalCraft transforms from a standalone GPU-accelerated media editor into an **Agentic Media-Production Platform** where:

- **Gemini** acts as the Creative Director — understanding user intent, analyzing media, generating structured EditPlans
- **Parallel** is the Research Department — providing external creative research, filmmaking references, trend analysis
- **Grafana** is the Production/Observability Department — monitoring processing performance, pipeline health, resource usage
- **Apple Metal** is the Rendering Engine — executing actual GPU compute shader processing on-device
- **The User** remains the Creative Authority — approving, guiding, and overriding AI decisions

## Architectural Metaphor

```
┌─────────────────────────────────────────────────┐
│                  USER (Creative Authority)        │
│                       │                           │
│                  User Intent                      │
│                       ▼                           │
│              ┌─────────────┐                     │
│              │   GEMINI    │◄──── Grafana Context │
│              │  (Director) │                     │
│              └──────┬──────┘                     │
│                     │                            │
│         ┌───────────┼───────────┐                │
│         ▼           ▼           ▼                │
│    ┌─────────┐ ┌──────────┐ ┌────────┐          │
│    │PARALLEL │ │ EditPlan │ │GRAFANA │          │
│    │Research │ │(Contract)│ │Observe │          │
│    └─────────┘ └────┬─────┘ └────────┘          │
│                     ▼                            │
│         ┌─────────────────────┐                  │
│         │    METALCRAFT       │                  │
│         │  ProcessingPipeline │                  │
│         │  MetalProcessor    │                  │
│         │  Metal GPU Shaders │                  │
│         └─────────┬───────────┘                  │
│                   ▼                              │
│            IMAGE / VIDEO                         │
└─────────────────────────────────────────────────┘
```

## Core Principles

1. **AI Decides, Metal Executes** — Gemini never directly touches MTLDevice, MTLTexture, or shader code
2. **Preserve What Works** — The existing Metal pipeline is production-grade and must not be rebuilt
3. **EditPlan as Contract** — All AI-to-editor communication flows through a validated, versioned EditPlan schema
4. **On-Device First** — Heavy media processing stays on the iPhone GPU; only metadata/prompts go to cloud
5. **Observe Everything** — Grafana receives telemetry so the agent can reason about actual processing performance
6. **User Authority** — The user can always override, approve, or reject AI suggestions
