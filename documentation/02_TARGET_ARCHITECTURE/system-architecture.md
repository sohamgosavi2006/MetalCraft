# MetalCraft — Distributed Agentic Media Platform System Architecture

## 1. Executive Overview

MetalCraft combines a cloud-hosted reasoning and telemetry control plane deployed on **Render** with a high-performance, on-device media execution engine running on **iOS (Apple Metal GPU & AVFoundation)**.

```text
                    USER / CREATOR
                          │
          ┌───────────────┴───────────────┐
          ▼                               ▼
   MetalCraft Web UI              MetalCraft iOS App
          │                               │
          │ HTTPS / WebSocket             │ HTTPS / WebSocket
          ▼                               ▼
   ─────────────────────────────────────────────────
               RENDER CLOUD CONTROL PLANE
   ─────────────────────────────────────────────────
          │               │               │
          ▼               ▼               ▼
     Google Gemini     Parallel AI     Grafana Cloud
    Creative Director   Research        Observability
          │
          ▼
   EditPlan & AudioPlan Synthesis (Schema 1.0)
          │
          │ Command Dispatch (/ws/ios)
          ▼
   ─────────────────────────────────────────────────
            iOS METAL GPU EXECUTION ENGINE
   ─────────────────────────────────────────────────
          │
          ▼
   Apple Metal Compute Shaders (30 FPS Frame Pipeline)
          │
          ▼
   AVFoundation Multi-Scene Composition & Audio Mixing
          │
          ▼
   Persistent VideoArtifact Creation & AVAsset Validation
          │
          ├─────────────────────────► Camera Roll (Photos)
          ├─────────────────────────► In-App Project Library
          └─────────────────────────► Render Progress Broadcast
```

---

## 2. Core Architectural Principles

1. **Cloud Intelligence & Orchestration**:
   - The cloud handles user intent parsing, cinematography reasoning, creative research queries, telemetry aggregation, and generation queue states.
   - Cloud **never** renders raw video frames or requires full-resolution media uploads from the device.

2. **On-Device GPU Execution**:
   - The iPhone executes frame-by-frame Metal shaders (Sobel, Gaussian blur, Swirl, Convolution, Color Grading).
   - High-throughput AVFoundation composition and audio ducking run locally with zero cloud compute cost or video upload latency.

3. **Privacy & Local Storage First**:
   - User photos and videos remain on the device.
   - Render stores only metadata, structured EditPlans, AudioPlans, device sessions, and audit events in a persistent SQLite store.

4. **Zero-Secret Client Footprint**:
   - `GEMINI_API_KEY`, `PARALLEL_API_KEY`, and `GRAFANA_TOKEN` remain strictly on the Render server.
   - iOS and Web clients communicate exclusively via authenticated backend endpoints.
