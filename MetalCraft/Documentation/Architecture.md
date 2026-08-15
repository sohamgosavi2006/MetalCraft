# Metal Craft — Architecture Specification

### Tagline
**Professional Image Processing Powered by Metal**

---

## 1. Overview & Architectural Goals

**Metal Craft** is an iOS application designed for professional-grade, GPU-accelerated image processing, real-time performance analysis, and educational visualization. The architecture strictly follows the **MVVM (Model-View-ViewModel)** design pattern with Swift 5.9's Observation framework (`@Observable`), decoupling UI components from the underlying Metal GPU compute pipeline and processing services.

---

## 2. Application Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                       SwiftUI Views                         │
│  (EditorView, EffectsView, PipelineView, PerformanceView,   │
│   AnalysisView, Canvas, Comparison, Controls)               │
└──────────────────────────────┬──────────────────────────────┘
                               │ Observes & Triggers Actions
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    AppState (@Observable)                   │
│   - Central Single Source of Truth                          │
│   - Holds Original/Processed Images, Pipeline State,        │
│     Performance Metrics, Undo/Redo Stacks, Preset Library   │
└──────────────┬───────────────────────────────┬──────────────┘
               │ Coordinates                   │ Delegates
               ▼                               ▼
┌──────────────────────────────┐ ┌────────────────────────────┐
│      Services & Utilities    │ │      Processing Pipeline   │
│  - ImageManager              │ │  - ProcessingPipeline      │
│  - ExportService             │ │  - PipelineNode            │
│  - PresetManager             │ │  - ProcessingOperation     │
│  - BenchmarkEngine           │ │  - ConvolutionKernel       │
│  - HistogramCalculator       │ └─────────────┬──────────────┘
└──────────────┬───────────────┘               │
               │                               ▼
               │                ┌─────────────────────────────┐
               └───────────────►│        MetalProcessor       │
                                │   - Pipeline State Cache    │
                                │   - Texture Pool Management │
                                │   - Compute Dispatching     │
                                └──────────────┬──────────────┘
                                               │ Encodes & Submits
                                               ▼
                                ┌─────────────────────────────┐
                                │      Metal GPU Hardware     │
                                │   - Compute Kernels         │
                                │   - Textures & Samplers     │
                                └─────────────────────────────┘
```

---

## 3. SwiftUI State & Concurrency Model

### 3.1 Observation (`@Observable`)
- `AppState` is marked with `@Observable` and isolated to `@MainActor`.
- Injected via `.environment(appState)` at the app root (`MetalCraftApp`).
- Child views read state via `@Environment(AppState.self)`.
- Eliminates unnecessary view invalidations compared to `ObservableObject`/`@Published`.

### 3.2 Threading & GPU Concurrency
1. **Main Thread (`@MainActor`)**:
   - UI rendering and interactions (gestures, sliders, navigation).
   - Lightweight state mutations and undo/redo pushes.
   - Command buffer encoding setup.
2. **Background Tasks (`Task.detached` / Swift Concurrency)**:
   - GPU command buffer execution waiting via `MTLCommandBuffer.addCompletedHandler` and checked continuations.
   - CPU reference benchmark algorithms.
   - CPU-based histogram calculation over raw pixel buffers.
   - Image file encoding (JPEG, PNG, HEIF).
3. **GPU Hardware Execution**:
   - Asynchronous compute shader grid dispatches.
   - Direct memory read/write between texture resources.

---

## 4. Image Data Flow & Non-Destructive Pipeline

1. **Import**: `PhotosPicker` -> `Data` -> `UIImage` -> `CGImage` -> `TextureLoader.textureFromUIImage` -> `originalTexture` (`MTLTexture` in `.bgra8Unorm`).
2. **Non-Destructive Execution**:
   - The `originalTexture` is never modified or discarded during edits.
   - When parameters or pipeline operations change, `MetalProcessor.process(pipeline:sourceTexture:)` executes sequentially through enabled nodes.
   - Uses an intermediate **Texture Pool** to ping-pong textures between sequential compute passes.
3. **Display**: The output `MTLTexture` is converted via `TextureLoader.uiImageFromTexture` to `UIImage` for display in SwiftUI canvas and before/after comparison modes.
4. **Export**: The full-resolution processed `MTLTexture` is extracted and encoded to JPEG, PNG, or HEIF with metadata preserved.

---

## 5. Memory Management & Safety

- **Texture Pooling**: `TexturePool` acquires and releases matching `MTLTexture` instances, eliminating per-frame memory allocation/deallocation overhead.
- **Maximum Resolution**: 8192×8192 pixel safety ceiling.
- **Memory Pressure Handling**: Listens for `UIApplication.didReceiveMemoryWarningNotification` to drain unused textures from the pool immediately.
- **Shared Storage Mode**: Uses `.storageMode = .shared` for seamless CPU upload and GPU compute access on iOS Unified Memory Architecture (UMA).
