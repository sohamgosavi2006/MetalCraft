# MetalCraft — Documentation

> **If you are Gemini and you are implementing changes, start with:**
> 1. Read `15_MASTER_GUIDES/GEMINI_IMPLEMENTATION_RULES.md` first
> 2. Then read `15_MASTER_GUIDES/IMPLEMENTATION_MASTER_PLAN.md`
> 3. Then read the relevant phase section and referenced architecture docs

---

## Documentation Index

```
documentation/
│
├── 00_PROJECT_OVERVIEW/
│   ├── README.md                  ← Project overview and tech stack
│   ├── VISION.md                  ← Product vision and philosophy
│   ├── GOALS.md                   ← Measurable project goals
│   ├── NON_GOALS.md               ← Explicit non-goals
│   └── GLOSSARY.md                ← Term definitions
│
├── 01_EXISTING_ARCHITECTURE/
│   └── CURRENT_ARCHITECTURE.md    ← Full repository analysis with dependency map
│
├── 02_TARGET_ARCHITECTURE/
│   └── TARGET_ARCHITECTURE.md     ← System architecture, data flow, security boundaries
│
├── 03_METAL_ENGINE/
│   └── METAL_GPU_ENGINE.md        ← MetalContext, MetalProcessor, TexturePool, shaders
│
├── 04_PIPELINE/
│   └── PROCESSING_PIPELINE.md     ← Pipeline model, undo/redo, presets, execution
│
├── 05_VIDEO/
│   └── VIDEO_ARCHITECTURE.md      ← VideoPlayerController, CVMetalTextureCache, export
│
├── 06_AGENTIC_AI/
│   ├── AGENT_ARCHITECTURE.md      ← Agent state machine, tools, feedback loop
│   └── EDIT_PLAN.md               ← EditPlan JSON schema (AI-to-editor contract)
│
├── 07_PARTNER_INTEGRATIONS/
│   ├── GRAFANA.md                 ← Grafana MCP integration (primary partner)
│   └── PARALLEL.md               ← Parallel MCP integration (secondary partner)
│
├── 08_CLOUD/
│   └── GOOGLE_CLOUD.md           ← Cloud Run, Secret Manager, IAM, deployment
│
├── 09_UI/
│   └── UI_ARCHITECTURE.md        ← Navigation, views, design system
│
├── 10_DATA_MODELS/
│   └── DATA_MODELS.md            ← All data models (existing + planned)
│
├── 11_TESTING/
│   └── TESTING_STRATEGY.md       ← Test plan, regression policy, manual checklist
│
├── 12_SECURITY/
│   └── SECURITY_ARCHITECTURE.md  ← Credentials, privacy, input validation
│
├── 13_ANALYTICS/
│   └── ANALYTICS_ARCHITECTURE.md ← Telemetry, observability, Grafana bridge
│
├── 14_HACKATHON/
│   └── ELIGIBILITY_RISK.md       ← Hackathon compliance analysis and strategy
│
├── 15_MASTER_GUIDES/
│   ├── IMPLEMENTATION_MASTER_PLAN.md  ← 15-phase implementation roadmap
│   ├── GEMINI_IMPLEMENTATION_RULES.md ← Rules for AI implementing changes
│   ├── ARCHITECTURE_DECISIONS.md      ← ADR-001 through ADR-010
│   └── RISK_REGISTER.md              ← 22 identified risks with mitigations
│
└── README.md                     ← THIS FILE (documentation index)
```

## Quick Start for Gemini

1. **Read** `15_MASTER_GUIDES/GEMINI_IMPLEMENTATION_RULES.md`
2. **Read** `15_MASTER_GUIDES/IMPLEMENTATION_MASTER_PLAN.md`
3. **Identify** which phase you are implementing
4. **Read** all architecture documents referenced by that phase
5. **Audit** the actual repository to confirm documentation accuracy
6. **Implement** the phase according to the plan
7. **Test** — all existing tests must pass + add new tests
8. **Report** using the Implementation Report Template

## Critical Documents

| Document | Purpose |
|----------|---------|
| `IMPLEMENTATION_MASTER_PLAN.md` | The entire 15-phase roadmap |
| `GEMINI_IMPLEMENTATION_RULES.md` | Rules you MUST follow |
| `CURRENT_ARCHITECTURE.md` | What exists today — DO NOT BREAK |
| `EDIT_PLAN.md` | The AI-to-editor contract — must be implemented exactly |
| `ELIGIBILITY_RISK.md` | Hackathon compliance — read before creating repos |
