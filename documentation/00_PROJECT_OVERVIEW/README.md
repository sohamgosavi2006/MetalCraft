# MetalCraft — Agentic Media-Production Platform

## Project Overview

**MetalCraft** is a native iOS application that combines GPU-accelerated image and video processing (via Apple Metal) with an agentic AI layer (via Gemini, Parallel, and Grafana) to create a professional media-production platform.

### Core Philosophy

```
AI decides → MetalCraft executes → Grafana observes → AI evaluates → AI adapts → Final media
```

### Technology Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| GPU Processing | Apple Metal (compute shaders) |
| Video | AVFoundation, Core Video, CVMetalTextureCache |
| AI Reasoning | Gemini (Google Cloud) |
| External Research | Parallel (MCP) |
| Observability | Grafana (MCP) |
| Cloud Platform | Google Cloud (Agent Development Kit, Cloud Run) |
| Media Library | Photos / PhotosUI |

### Product Sections

| Tab | Status | Purpose |
|-----|--------|---------|
| Editor | ✅ IMPLEMENTED | Primary image/video editing workspace |
| AI Create | 🔲 PLACEHOLDER | Future agentic creative workflows |
| Analytics | ✅ IMPLEMENTED | Processing telemetry, benchmarks, histograms |
| Projects | ✅ IMPLEMENTED | Multi-image/video project management |

### Target Vision

> "An Agentic Media-Production Platform where Gemini acts as a Creative Director, Parallel provides external creative research, Grafana provides production observability and runtime context, and Apple Metal performs the actual GPU-accelerated image/video processing."

See [VISION.md](VISION.md) for the complete product vision.
See [GOALS.md](GOALS.md) for measurable goals.
See [NON_GOALS.md](NON_GOALS.md) for explicit non-goals.
See [GLOSSARY.md](GLOSSARY.md) for terminology definitions.
