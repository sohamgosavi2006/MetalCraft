# Current Architecture — Repository Analysis

> **Source of Truth**: The GitHub repository and local Xcode project at `MetalCraft/`
> **Last Inspected**: 2026-08-15

---

## Repository Structure

```
MetalCraft/
├── MetalCraft.xcodeproj/           # Xcode project configuration
├── MetalCraft/                     # Main application target
│   ├── App/
│   │   └── AppState.swift          # Central @Observable ViewModel (1131 lines)
│   ├── Assets.xcassets/            # App icon, accent color, asset catalog
│   ├── ContentView.swift           # TabView container (Editor, AI Create, Analytics, Projects)
│   ├── Documentation/              # Existing inline documentation
│   ├── Info.plist                  # App configuration (Photos usage descriptions)
│   ├── Metal/
│   │   ├── MetalContext.swift      # MTLDevice + MTLCommandQueue + MTLLibrary singleton
│   │   ├── MetalProcessor.swift    # GPU compute shader dispatch engine (21KB)
│   │   ├── TextureLoader.swift     # UIImage ↔ MTLTexture conversion
│   │   └── TexturePool.swift       # Reusable MTLTexture pool
│   ├── MetalCraft-Bridging-Header.h # Objective-C/Metal bridging header
│   ├── MetalCraft.entitlements     # App entitlements
│   ├── Models/
│   │   ├── AdjustmentParams.swift         # 7-param photographic adjustments
│   │   ├── AdjustmentParams+Codable.swift # Codable conformance
│   │   ├── AnalyticsModels.swift          # Analytics data models
│   │   ├── ComparisonMode.swift           # Original/Processed/SideBySide/Split
│   │   ├── ConvolutionKernel.swift        # Custom 3×3 convolution kernels
│   │   ├── DistortionParams.swift         # Ripple/Swirl distortion parameters
│   │   ├── EducationalInfo.swift          # Educational content for Metal concepts
│   │   ├── Errors.swift                   # Error types (ImageError, ExportError, etc.)
│   │   ├── ExportFormat.swift             # JPEG/PNG/HEIF export formats
│   │   ├── HistogramData.swift            # RGBA histogram data model
│   │   ├── PerformanceMetrics.swift       # GPU timing, pass count metrics
│   │   ├── PipelineNode.swift             # Single node in processing pipeline
│   │   ├── Preset.swift                   # Named pipeline+adjustments snapshot
│   │   ├── ProcessingOperation.swift      # Enum of all GPU operations
│   │   ├── ProcessingPipeline.swift       # Ordered node list with mutations
│   │   └── Project.swift                  # Project, ProjectImage, ProjectVideo models
│   ├── Services/
│   │   ├── BenchmarkEngine.swift          # CPU vs GPU benchmark service
│   │   ├── ExportService.swift            # Image export (JPEG/PNG/HEIF)
│   │   ├── HistogramCalculator.swift      # RGBA histogram from MTLTexture
│   │   ├── ImageManager.swift             # Image import/metadata extraction
│   │   ├── PresetManager.swift            # Preset persistence
│   │   ├── ProjectManager.swift           # Project CRUD + file storage
│   │   ├── VideoExportService.swift       # GPU-rendered video export with AVAssetWriter
│   │   ├── VideoManager.swift             # Video metadata extraction
│   │   ├── VideoPlayerController.swift    # AVPlayer + CADisplayLink frame sync
│   │   └── VideoTextureProvider.swift     # CVPixelBuffer → MTLTexture via CVMetalTextureCache
│   ├── Shaders/
│   │   ├── ShaderTypes.h                  # C struct definitions shared with Metal
│   │   └── Shaders.metal                  # All Metal compute kernels (308 lines)
│   └── Views/
│       ├── AICreate/
│       │   └── AICreateView.swift         # PLACEHOLDER — "Coming Soon"
│       ├── Analysis/
│       │   ├── AnalysisView.swift
│       │   ├── HistogramView.swift
│       │   ├── ImageInfoView.swift
│       │   └── RGBHistogramView.swift
│       ├── Analytics/
│       │   └── AnalyticsView.swift
│       ├── Edit/
│       │   └── EditView.swift
│       ├── Editor/
│       │   ├── AdjustmentPanelView.swift
│       │   ├── AdjustmentSliderRow.swift
│       │   ├── ComparisonView.swift
│       │   ├── EditorView.swift           # Main editor workspace (740 lines)
│       │   ├── ImageCanvasView.swift
│       │   ├── MetalVideoView.swift       # MTKView-based GPU video renderer
│       │   ├── PipelineControlView.swift
│       │   ├── PresetPickerSheet.swift
│       │   ├── PresetsControlView.swift
│       │   ├── SplitComparisonView.swift
│       │   └── VideoCanvasView.swift
│       ├── Effects/
│       │   ├── ConvolutionLabView.swift
│       │   ├── EffectCategoryList.swift
│       │   ├── EffectParameterView.swift
│       │   └── EffectsView.swift
│       ├── Performance/
│       │   ├── BenchmarkControlView.swift
│       │   ├── BenchmarkResultsView.swift
│       │   ├── GPUDashboardView.swift
│       │   ├── MetricCard.swift
│       │   └── PerformanceView.swift
│       ├── Pipeline/
│       │   ├── AddOperationSheet.swift
│       │   ├── PipelineNodeRow.swift
│       │   └── PipelineView.swift
│       ├── Projects/
│       │   ├── ImagePreviewSheet.swift
│       │   ├── NewProjectSheet.swift
│       │   ├── ProjectDetailsView.swift
│       │   ├── ProjectPickerSheet.swift
│       │   ├── ProjectsView.swift
│       │   └── VideoPreviewSheet.swift
│       └── Shared/
│           ├── EducationalSheet.swift
│           ├── EmptyStateView.swift
│           ├── ShareSheet.swift
│           └── Theme.swift
├── MetalCraftTests/
│   └── MetalCraftTests.swift              # 13 unit tests (all passing)
└── MetalCraftUITests/
    ├── MetalCraftUITests.swift
    └── MetalCraftUITestsLaunchTests.swift
```

---

## Component Dependency Map

```
MetalContext (Sendable, singleton)
├── device: MTLDevice
├── commandQueue: MTLCommandQueue
└── library: MTLLibrary
    │
    ▼
MetalProcessor (depends on MetalContext)
├── Uses MTLComputePipelineState for each shader
├── Dispatches compute commands via MTLCommandBuffer
├── Reads from input MTLTexture, writes to output MTLTexture
└── Supports: adjustments, grayscale, invert, gaussianBlur, sharpen,
              sobelEdge, pixelate, ripple, swirl, convolution
    │
    ▼
TexturePool (depends on MetalContext.device)
├── Caches reusable MTLTextures by (width, height, pixelFormat)
└── Avoids repeated GPU memory allocation
    │
    ▼
AppState (@Observable, @MainActor)
├── Owns: MetalContext, MetalProcessor, BenchmarkEngine, HistogramCalculator,
│         ProjectManager, ImageManager, ExportService, PresetManager,
│         VideoTextureProvider, VideoManager, VideoExportService, VideoPlayerController
├── Pipeline: ProcessingPipeline (ordered PipelineNode list)
├── Adjustments: AdjustmentParams
├── Image State: originalImage, originalTexture, processedTexture, displayImage
├── Video State: currentVideoURL, videoInfo, VideoPlayerController
├── Projects: [Project], currentProject, currentProjectImage, currentProjectVideo
├── Analytics: performanceMetrics, histogramData, benchmarkResults, processingHistory
├── Undo/Redo: undoStack/redoStack of ProcessingPipeline snapshots
└── Navigation: selectedTab (AppTab), comparisonMode, splitPosition
```

---

## Metal GPU Processing Flow

### Image Processing

```
UIImage (user import via PhotosPicker)
    │
    ▼
TextureLoader.textureFromUIImage()
    │
    ▼
MTLTexture (originalTexture, stored on AppState)
    │
    ▼
ProcessingPipeline.enabledNodes  →  for each PipelineNode:
    │
    ▼
MetalProcessor.process(operation, inputTexture, outputTexture)
    │   ├── Creates MTLComputePipelineState from shader function name
    │   ├── Creates MTLCommandBuffer from MetalContext.commandQueue
    │   ├── Encodes compute command with input/output textures + parameter buffer
    │   ├── Dispatches threadgroups (16×16 threads)
    │   └── Commits and waits for completion
    │
    ▼
Result MTLTexture (processedTexture, stored on AppState)
    │
    ▼
TextureLoader.uiImageFromTexture() → displayImage for SwiftUI
```

### Video Processing

```
Video URL (user import via PhotosPicker)
    │
    ▼
AVURLAsset → AVPlayerItem → AVPlayerItemVideoOutput
    │
    ▼
CADisplayLink (30-60Hz frame sync)
    │
    ▼
AVPlayerItemVideoOutput.copyPixelBuffer(forItemTime:)
    │
    ▼
CVPixelBuffer
    │
    ▼
VideoTextureProvider.textureFromPixelBuffer()
    │   └── CVMetalTextureCache → CVMetalTexture → MTLTexture (zero-copy)
    │
    ▼
MTLTexture (currentRawTexture on VideoPlayerController)
    │
    ▼
MetalProcessor.process() (same pipeline as images)
    │
    ▼
MTLTexture (currentProcessedTexture)
    │
    ▼
MetalVideoView (MTKView) → CIImage with preferredTransform → Direct GPU drawable render
```

---

## Existing Metal Shaders (Shaders.metal)

| Kernel Function | Operation | Parameters |
|----------------|-----------|-----------|
| `adjustments_kernel` | 7-param photographic adjustments | AdjustmentParams (brightness, contrast, exposure, saturation, temperature, tint, gamma) |
| `grayscale_kernel` | BT.709 luminance conversion | None |
| `invert_kernel` | RGB color inversion | None |
| `gaussian_blur_h_kernel` | Horizontal Gaussian blur pass | GaussianBlurParams (radius, weights, texSize) |
| `gaussian_blur_v_kernel` | Vertical Gaussian blur pass | GaussianBlurParams |
| `convolution_kernel` | Generic 3×3 convolution | ConvolutionParams (weights[9], divisor, bias, strength) |
| `sobel_kernel` | Sobel edge detection | EffectParams (strength, blend) |
| `pixelate_kernel` | Mosaic/pixelation | EffectParams (blockSize) |
| `ripple_kernel` | Radial ripple distortion | DistortionParams (center, radius, frequency, strength, phase) |
| `swirl_kernel` | Spiral swirl distortion | DistortionParams (center, radius, strength) |

---

## Existing Services

| Service | File | Purpose | Status |
|---------|------|---------|--------|
| MetalContext | Metal/MetalContext.swift | MTLDevice + Queue + Library singleton | ✅ COMPLETE |
| MetalProcessor | Metal/MetalProcessor.swift | GPU shader dispatch for all operations | ✅ COMPLETE |
| TexturePool | Metal/TexturePool.swift | Reusable MTLTexture cache | ✅ COMPLETE |
| TextureLoader | Metal/TextureLoader.swift | UIImage ↔ MTLTexture conversion | ✅ COMPLETE |
| VideoTextureProvider | Services/VideoTextureProvider.swift | CVPixelBuffer → MTLTexture via CVMetalTextureCache | ✅ COMPLETE |
| VideoPlayerController | Services/VideoPlayerController.swift | AVPlayer + CADisplayLink frame extraction | ✅ COMPLETE |
| VideoManager | Services/VideoManager.swift | Video metadata extraction (duration, FPS, resolution, codec) | ✅ COMPLETE |
| VideoExportService | Services/VideoExportService.swift | GPU-rendered video export via AVAssetWriter | ✅ COMPLETE |
| BenchmarkEngine | Services/BenchmarkEngine.swift | CPU vs GPU comparative benchmarks | ✅ COMPLETE |
| HistogramCalculator | Services/HistogramCalculator.swift | RGBA histogram computation from MTLTexture | ✅ COMPLETE |
| ImageManager | Services/ImageManager.swift | Image import + metadata extraction | ✅ COMPLETE |
| ExportService | Services/ExportService.swift | Image export (JPEG/PNG/HEIF) + Photos save | ✅ COMPLETE |
| ProjectManager | Services/ProjectManager.swift | Project CRUD + file-system persistence | ✅ COMPLETE |
| PresetManager | Services/PresetManager.swift | Preset save/load persistence | ✅ COMPLETE |

---

## Existing Models

| Model | File | Status |
|-------|------|--------|
| Project, ProjectImage, ProjectVideo | Models/Project.swift | ✅ Multi-image + multi-video |
| MediaType | Models/Project.swift | ✅ .image / .video |
| VideoInfo | Models/Project.swift | ✅ Duration, resolution, FPS, codec, fileSize |
| ProcessingOperation | Models/ProcessingOperation.swift | ✅ 10 GPU operations |
| OperationCategory | Models/ProcessingOperation.swift | ✅ 8 categories |
| ProcessingPipeline | Models/ProcessingPipeline.swift | ✅ Ordered nodes, mutations, serialization |
| PipelineNode | Models/PipelineNode.swift | ✅ Operation + enabled flag |
| AdjustmentParams | Models/AdjustmentParams.swift | ✅ 7 photographic parameters |
| ComparisonMode | Models/ComparisonMode.swift | ✅ 4 modes |
| ConvolutionKernel | Models/ConvolutionKernel.swift | ✅ Custom 3×3 kernels |
| Preset | Models/Preset.swift | ✅ Named pipeline snapshots |
| HistogramData | Models/HistogramData.swift | ✅ RGBA histogram |
| PerformanceMetrics | Models/PerformanceMetrics.swift | ✅ GPU timing metrics |
| ExportFormat | Models/ExportFormat.swift | ✅ JPEG/PNG/HEIF |

---

## Existing Views

| View | File | Status | Purpose |
|------|------|--------|---------|
| ContentView | ContentView.swift | ✅ | TabView container |
| EditorView | Views/Editor/EditorView.swift | ✅ | Primary editing workspace with tool tabs |
| ImageCanvasView | Views/Editor/ImageCanvasView.swift | ✅ | Image preview with zoom/pan |
| VideoCanvasView | Views/Editor/VideoCanvasView.swift | ✅ | Video preview with timeline |
| MetalVideoView | Views/Editor/MetalVideoView.swift | ✅ | MTKView GPU video renderer |
| AdjustmentPanelView | Views/Editor/AdjustmentPanelView.swift | ✅ | 7-slider adjustment controls |
| EffectCategoryList | Views/Effects/EffectCategoryList.swift | ✅ | Effect browsing by category |
| PipelineControlView | Views/Editor/PipelineControlView.swift | ✅ | DAG node execution graph |
| PresetsControlView | Views/Editor/PresetsControlView.swift | ✅ | Preset selection |
| ComparisonView | Views/Editor/ComparisonView.swift | ✅ | Original/Processed comparison |
| SplitComparisonView | Views/Editor/SplitComparisonView.swift | ✅ | Draggable split divider |
| AnalyticsView | Views/Analytics/AnalyticsView.swift | ✅ | Analytics dashboard |
| AnalysisView | Views/Analysis/AnalysisView.swift | ✅ | Image analysis panel |
| HistogramView | Views/Analysis/HistogramView.swift | ✅ | Histogram visualization |
| ProjectsView | Views/Projects/ProjectsView.swift | ✅ | Project browser |
| ProjectDetailsView | Views/Projects/ProjectDetailsView.swift | ✅ | Project detail with images/videos |
| AICreateView | Views/AICreate/AICreateView.swift | 🔲 PLACEHOLDER | "Coming Soon" empty state |

---

## What Must Remain Unchanged

| Component | Reason |
|-----------|--------|
| MetalContext | Foundation of all GPU operations |
| MetalProcessor | Core shader dispatch engine |
| Shaders.metal | All 10 GPU compute kernels |
| ShaderTypes.h | C struct definitions shared with Metal |
| TexturePool | Memory management for GPU resources |
| ProcessingPipeline | Core editing model |
| ProcessingOperation | All existing operation definitions |
| AppState (core properties) | Single source of truth |
| Project/ProjectImage/ProjectVideo | Persistence model |
| VideoPlayerController | Real-time video frame extraction |
| VideoTextureProvider | Zero-copy CVPixelBuffer → MTLTexture |
| All existing Views (Editor, Analytics, Projects) | UI that works today |

## What Should Be Extended

| Component | Extension Needed |
|-----------|-----------------|
| AppState | Add agent state, telemetry emission, EditPlan execution |
| ProcessingOperation | May need new operations requested by agent |
| AICreateView | Replace placeholder with agentic UI |
| ExportService | May need agent-triggered export |
| AnalyticsView | Add agent activity telemetry |

## What Is New

| Component | Purpose |
|-----------|---------|
| EditPlan schema | AI-to-editor contract |
| AgentService | iOS ↔ Cloud agent communication |
| TelemetryService | Emit processing telemetry to Grafana |
| EditPlanExecutor | Translate EditPlan → ProcessingPipeline |
| Cloud Agent (Python/ADK) | Gemini agent with tool definitions |
| MCP integrations | Parallel + Grafana tool servers |
