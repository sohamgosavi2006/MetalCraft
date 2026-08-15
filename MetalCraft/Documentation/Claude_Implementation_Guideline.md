# MetalCraft — GPU Image Lab V1: Complete Implementation Specification

> [!IMPORTANT]
> This document is the definitive engineering blueprint for Google Gemini to implement MetalCraft (GPU Image Lab V1).
> Every architectural decision, shader algorithm, data model, and file is specified.
> Gemini must follow this document step-by-step without inventing architecture.

---

## 1. Executive Summary

**MetalCraft** (display name: **GPU Image Lab**) is a professional iOS application that demonstrates real GPU image processing through Apple's Metal framework. It is NOT a generic photo editor, social media app, or AI image generator. It is a focused, polished tool that:

1. Imports images and processes them through a configurable Metal GPU pipeline
2. Provides professional adjustments (brightness, contrast, exposure, saturation, temperature, tint, gamma)
3. Implements GPU effects (grayscale, invert, Gaussian blur, sharpen, Sobel edge detection, pixelation, ripple distortion, swirl distortion)
4. Features a Convolution Lab with custom 3×3 kernel support
5. Displays real GPU performance metrics and CPU vs GPU benchmarks
6. Provides image analysis with RGB/luminance histograms
7. Supports non-destructive editing with a visual processing pipeline, undo/redo, and presets

**Existing Project State**: The Xcode project `MetalCraft` already exists at the workspace path with:
- Bundle ID: `com.sohamgosavi.MetalCraft`
- Development Team: `78FKQ9UNPX`
- Deployment Target: iOS 26.5 (the project was created with Xcode 26.6)
- Uses `PBXFileSystemSynchronizedRootGroup` — all files placed under `MetalCraft/` are automatically included in the build
- Currently has default SwiftData boilerplate that will be completely replaced

**Key Constraint**: Must work on iPhone 11 (A13 Bionic, Metal feature set Apple GPU Family 6). The deployment target set in the project is iOS 26.5 — iPhone 11 supports this since Apple provides iOS 26 for A13 and later.

---

## 2. Product Definition

### 2.1 What This App IS
- Professional image processing powered by Metal GPU compute shaders
- GPU performance analysis and visualization tool
- Educational demonstration of GPU computing concepts
- Non-destructive image editing pipeline

### 2.2 What This App IS NOT
- Social media app / Instagram clone
- Generic photo editor with dozens of artistic filters
- AI photo generator
- Cloud application
- 3D application
- Camera application

### 2.3 Core Data Flow

```
UIImage (from Photos)
  → CGImage
  → MTLTexture (originalTexture)
  → Pipeline Stage 1 (e.g., Brightness compute shader)
  → Pipeline Stage 2 (e.g., Contrast compute shader)
  → ...Pipeline Stage N
  → MTLTexture (processedTexture)
  → CGImage (for SwiftUI display & export)
```

### 2.4 Display Name vs Project Name
- **Xcode Project Name**: MetalCraft
- **App Display Name**: GPU Image Lab (set via `CFBundleDisplayName` in Info.plist)
- **Bundle ID**: `com.sohamgosavi.MetalCraft` (already configured)

---

## 3. V1 Scope — Complete Feature List

### INCLUDED in V1

| Category | Features |
|----------|----------|
| Image Management | Import from Photos (PNG, JPEG, HEIF), preview, zoom, pan, fit-to-screen, reset zoom |
| Adjustments | Brightness, Contrast, Exposure, Saturation, Temperature, Tint, Gamma |
| Basic Effects | Grayscale, Invert |
| Blur | Gaussian Blur (separable, two-pass) |
| Sharpen | Unsharp mask / convolution sharpen |
| Edge Detection | Sobel (X + Y gradient) |
| Pixelation | Mosaic / block pixelation |
| Distortion | Ripple, Swirl |
| Convolution Lab | Built-in kernels (Blur, Sharpen, Edge, Emboss) + Custom 3×3 kernel |
| Pipeline | Non-destructive, reorderable, enable/disable per node |
| Comparison | Original, Processed, Side-by-side, Split (draggable divider) |
| Performance | Real GPU timing, pixel count, GPU passes, frame time |
| Benchmark | CPU vs GPU across 512², 1024², 2048², 4096² |
| Analysis | RGB histogram, Luminance histogram, resolution, format, channels, bit depth |
| Educational | Per-effect algorithm explanation + Metal concept |
| Presets | 5 built-in + save/load/delete custom presets |
| Undo/Redo | Lightweight state-based (not texture-based) |
| Reset | Per-adjustment, per-effect, pipeline, image, zoom |
| Export | JPEG, PNG, HEIF |

### EXCLUDED from V1 (V2 only)
- Video processing
- Real-time camera input
- Batch processing
- Layer compositing
- Custom shader editor
- Network/cloud features
- Additional edge-detection algorithms (Prewitt, Laplacian, Canny)
- Additional distortion modes beyond Ripple and Swirl
- iPad-specific multi-pane layouts
- Metal ray tracing
- Machine learning integration
- HDR tone mapping

---

## 4. UX Architecture

### 4.1 Navigation Structure

The app uses a `TabView` with 5 tabs at the bottom:

```
GPU Image Lab (TabView)
│
├── Tab 1: Editor        (Image canvas + adjustment sliders)
├── Tab 2: Effects       (Effect selection + parameters)
├── Tab 3: Pipeline      (Visual pipeline editor)
├── Tab 4: Performance   (GPU metrics + benchmark)
└── Tab 5: Analysis      (Histograms + image info)
```

**Rationale**: A bottom tab bar is the most natural iOS navigation pattern for 5 top-level sections. It keeps all sections one tap away and avoids deeply nested navigation stacks on small iPhone screens.

### 4.2 Tab Descriptions

#### Tab 1: Editor
- **Top**: Toolbar with import button, comparison mode picker, undo/redo buttons, export button
- **Center**: Image canvas (scrollable, zoomable) showing either original or processed image
- **Bottom**: Scrollable adjustment panel with sliders for Brightness, Contrast, Exposure, Saturation, Temperature, Tint, Gamma
- **Empty State**: "Import an image to begin" with prominent import button

#### Tab 2: Effects
- **Top**: Same image canvas (smaller, non-scrollable preview)
- **Center**: Categorized effect list (Basic, Blur, Sharpen, Edge, Pixelation, Distortion, Convolution Lab)
- **Bottom**: Parameter controls for selected effect
- **Interaction**: Tapping an effect adds it to the pipeline; parameters are live-previewed

#### Tab 3: Pipeline
- **Top**: Small image preview
- **Center**: Vertical list of pipeline nodes, each showing:
  - Effect/adjustment name
  - Enable/disable toggle
  - Parameter summary
  - Delete button
  - Drag handle for reordering
- **Bottom**: "Add Operation" button, "Reset Pipeline" button
- **Interaction**: Tap a node to edit its parameters; long-press and drag to reorder

#### Tab 4: Performance
- **Top Section**: GPU Performance Dashboard (current effect, GPU time, resolution, pixel count, passes, frame time)
- **Middle Section**: Benchmark launcher (select operation, run benchmark across resolutions)
- **Bottom Section**: Benchmark results table and speedup chart
- **Empty State**: "Process an image to see GPU metrics"

#### Tab 5: Analysis
- **Top**: RGB Histogram (overlaid R, G, B channels)
- **Middle**: Luminance Histogram
- **Bottom**: Image Information table (resolution, pixel count, format, channels, bit depth)
- **Empty State**: "Import an image to see analysis"

### 4.3 iPhone Screen Constraints

- All views must work in portrait on 5.8" (iPhone 11) through current sizes
- Adjustment sliders use compact height (44pt touch target)
- Image canvas gets maximum vertical space
- Controls panels use `ScrollView` to handle overflow
- Pipeline nodes are compact list rows (60pt height)
- Histograms use ~120pt height each
- Use `GeometryReader` sparingly — only for the split comparison divider and image canvas

### 4.4 States

| State | UI Behavior |
|-------|-------------|
| Empty (no image) | Show centered import prompt with SF Symbol `photo.badge.plus` |
| Loading | Show `ProgressView` overlay on canvas |
| Loaded (original) | Show image, enable all controls |
| Processing | Show subtle activity indicator; controls remain interactive |
| Error | Show alert with localized description + dismiss button |
| Comparison | Show comparison mode UI based on selected mode |

### 4.5 Accessibility
- All sliders have `accessibilityLabel` and `accessibilityValue`
- All buttons have `accessibilityLabel`
- Images have `accessibilityLabel("Processed image")`
- Use semantic colors that respect Dark/Light mode
- Minimum touch target 44×44pt

---

## 5. Application Architecture

### 5.1 Architecture Pattern: MVVM

```
View (SwiftUI) → ViewModel (@Observable) → Services/Managers → Metal
```

- **Views**: SwiftUI views, no business logic
- **ViewModels**: `@Observable` classes (Swift 5.9 Observation macro), hold state and coordinate between views and services
- **Models**: Plain structs (Codable, Identifiable, Sendable where needed)
- **Services**: Metal processor, image loader, export service, preset storage, benchmark engine
- **Metal**: Shader functions, pipeline states, texture management

### 5.2 Key Components Overview

```
MetalCraftApp (entry point)
  └─ AppState (@Observable, @MainActor)
       ├─ ImageManager (image loading, state)
       ├─ PipelineManager (operation list, ordering)
       ├─ MetalProcessor (GPU processing engine)
       ├─ PerformanceTracker (timing, metrics)
       ├─ BenchmarkEngine (CPU vs GPU benchmarks)
       ├─ HistogramCalculator (image analysis)
       ├─ PresetManager (save/load presets)
       ├─ UndoManager (lightweight state undo/redo)
       └─ ExportService (image export)
```

---

## 6. SwiftUI Architecture

### 6.1 State Management Strategy

#### Source of Truth: `AppState`

```swift
@Observable
@MainActor
final class AppState {
    // Image state
    var originalImage: UIImage? = nil
    var originalTexture: MTLTexture? = nil
    var processedTexture: MTLTexture? = nil
    var displayImage: UIImage? = nil
    
    // Pipeline
    var pipeline: ProcessingPipeline = ProcessingPipeline()
    
    // UI state
    var selectedTab: AppTab = .editor
    var comparisonMode: ComparisonMode = .processed
    var splitPosition: CGFloat = 0.5
    var isProcessing: Bool = false
    var isImporting: Bool = false
    var errorMessage: String? = nil
    var showError: Bool = false
    
    // Zoom state
    var zoomScale: CGFloat = 1.0
    var zoomOffset: CGSize = .zero
    
    // Performance
    var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    var benchmarkResults: [BenchmarkResult] = []
    var isBenchmarking: Bool = false
    
    // Analysis
    var histogramData: HistogramData? = nil
    var imageInfo: ImageInfo? = nil
    
    // Undo/Redo
    var undoStack: [PipelineSnapshot] = []
    var redoStack: [PipelineSnapshot] = []
    
    // Presets
    var presets: [Preset] = []
    var builtInPresets: [Preset] = Preset.builtInPresets
    
    // Services (non-published)
    let metalProcessor: MetalProcessor
    let imageManager: ImageManager
    let exportService: ExportService
    let benchmarkEngine: BenchmarkEngine
    let histogramCalculator: HistogramCalculator
    let presetManager: PresetManager
}
```

**Why `@Observable` instead of `ObservableObject`**: The `@Observable` macro (Swift 5.9 / iOS 17+) provides fine-grained observation. SwiftUI views only re-render when properties they actually read change, unlike `@Published` which notifies on every change to any property. Since our deployment target is iOS 26.5, `@Observable` is fully available.

#### View State Distribution

| Property | Owner | SwiftUI Attribute |
|----------|-------|-------------------|
| `AppState` | `MetalCraftApp` | `@State` (since @Observable) |
| Tab-specific UI state | Individual views | `@State` |
| Sheet/alert presentation | Individual views | `@State` |
| Gesture state (zoom drag) | Canvas view | `@GestureState` |
| Filter parameter editing | FilterEditorView | Local `@State` copy, committed on change |

#### Passing `AppState` Through Views

```swift
// In MetalCraftApp:
@State private var appState = AppState()

var body: some Scene {
    WindowGroup {
        ContentView()
            .environment(appState)
    }
}

// In child views:
@Environment(AppState.self) private var appState
```

**Why `@Environment` over `@EnvironmentObject`**: With `@Observable`, use `.environment()` / `@Environment(AppState.self)`. This is the modern pattern. `@EnvironmentObject` is for `ObservableObject` only.

### 6.2 View Hierarchy

```
MetalCraftApp
└── ContentView
    └── TabView
        ├── EditorView
        │   ├── EditorToolbar
        │   ├── ImageCanvasView
        │   │   ├── ZoomableImageView
        │   │   └── SplitComparisonOverlay (conditional)
        │   └── AdjustmentPanelView
        │       ├── AdjustmentSliderRow (×7)
        │       └── ResetAdjustmentsButton
        ├── EffectsView
        │   ├── EffectPreviewView
        │   ├── EffectCategoryList
        │   │   └── EffectRow (per effect)
        │   ├── EffectParameterView (conditional)
        │   └── ConvolutionLabView (conditional)
        │       ├── KernelGridView
        │       ├── PresetKernelPicker
        │       └── KernelApplyButton
        ├── PipelineView
        │   ├── PipelinePreviewView
        │   ├── PipelineNodeList (List with .onMove, .onDelete)
        │   │   └── PipelineNodeRow
        │   │       ├── EnableToggle
        │   │       ├── ParameterSummary
        │   │       └── DeleteButton
        │   ├── AddOperationButton
        │   └── ResetPipelineButton
        ├── PerformanceView
        │   ├── GPUDashboardView
        │   │   ├── MetricCard (×N)
        │   │   └── ProcessingTimeline
        │   ├── BenchmarkControlView
        │   │   ├── OperationPicker
        │   │   └── RunBenchmarkButton
        │   └── BenchmarkResultsView
        │       ├── ResultsTable
        │       └── SpeedupChartView
        └── AnalysisView
            ├── RGBHistogramView
            ├── LuminanceHistogramView
            ├── ImageInfoView
            └── EducationalInfoView
```

---

## 7. Metal Architecture

### 7.1 Core Metal Objects

#### `MetalContext` — Singleton-like Shared State

```swift
final class MetalContext: Sendable {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        guard let commandQueue = device.makeCommandQueue() else { return nil }
        guard let library = device.makeDefaultLibrary() else { return nil }
        self.device = device
        self.commandQueue = commandQueue
        self.library = library
    }
}
```

**Why a dedicated class**: `MTLDevice`, `MTLCommandQueue`, and `MTLLibrary` are expensive to create and must be reused. This class is created once at app launch and shared. It is `Sendable` because all three Metal protocol types are thread-safe.

**Why NOT a singleton**: It is created in `MetalCraftApp` and injected via dependency injection (passed to `AppState`'s initializer). This makes testing possible and avoids hidden global state.

#### `MetalProcessor` — The Processing Engine

```swift
@MainActor
final class MetalProcessor {
    let context: MetalContext
    
    // Cached pipeline states
    private var computePipelines: [String: MTLComputePipelineState] = [:]
    
    // Texture pool
    private var texturePool: TexturePool
    
    // Sampler
    let nearestSampler: MTLSamplerState
    let linearSampler: MTLSamplerState
    
    init(context: MetalContext) { ... }
    
    // Core processing
    func process(pipeline: ProcessingPipeline, 
                 sourceTexture: MTLTexture) async throws -> (MTLTexture, PerformanceMetrics)
    
    // Individual operations
    func applyAdjustment(_ params: AdjustmentParameters, 
                         source: MTLTexture, 
                         destination: MTLTexture, 
                         commandBuffer: MTLCommandBuffer) throws
    
    func applyEffect(_ effect: EffectConfiguration, 
                     source: MTLTexture, 
                     destination: MTLTexture, 
                     commandBuffer: MTLCommandBuffer) throws
    
    // Pipeline state management
    func getOrCreatePipeline(functionName: String) throws -> MTLComputePipelineState
    
    // Texture management
    func createTexture(width: Int, height: Int, 
                       usage: MTLTextureUsage, 
                       pixelFormat: MTLPixelFormat) -> MTLTexture?
}
```

**Why `@MainActor`**: `MetalProcessor` holds mutable cached state (`computePipelines`, `texturePool`). Making it `@MainActor` ensures thread-safe access without manual locking. Metal command buffer submission and GPU execution are asynchronous regardless — calling `commandBuffer.commit()` on the main thread does NOT block the main thread; the GPU executes independently.

**Why NOT an actor**: `actor` isolation would require `await` for every property access from the views, adding complexity. Since all UI-initiated processing already goes through `AppState` (which is `@MainActor`), keeping `MetalProcessor` on `@MainActor` is simpler and equally safe.

### 7.2 Texture Management

#### `TexturePool` — Avoid Redundant Allocation

```swift
struct TexturePool {
    private var available: [TextureKey: [MTLTexture]] = [:]
    
    struct TextureKey: Hashable {
        let width: Int
        let height: Int
        let pixelFormat: MTLPixelFormat
    }
    
    mutating func acquire(device: MTLDevice, width: Int, height: Int,
                          pixelFormat: MTLPixelFormat = .bgra8Unorm,
                          usage: MTLTextureUsage = [.shaderRead, .shaderWrite]) -> MTLTexture?
    
    mutating func release(_ texture: MTLTexture)
    
    mutating func drain()
}
```

**Rationale**: Creating `MTLTexture` objects is expensive. A multi-pass pipeline (e.g., separable Gaussian blur) needs intermediate textures. Rather than creating and destroying textures per frame, the pool caches textures by dimension and format. After processing completes, intermediate textures are returned to the pool.

#### Texture Configuration

| Texture Role | Pixel Format | Usage Flags | Notes |
|---|---|---|---|
| Original (source) | `.bgra8Unorm` | `.shaderRead` | Created once from imported image |
| Intermediate (ping-pong) | `.bgra8Unorm` | `[.shaderRead, .shaderWrite]` | From texture pool; reused across pipeline stages |
| Final (processed) | `.bgra8Unorm` | `[.shaderRead, .shaderWrite]` | The output; also serves as input for next re-render |
| Gaussian blur temp | `.bgra8Unorm` | `[.shaderRead, .shaderWrite]` | Horizontal pass output / vertical pass input |

**Why `.bgra8Unorm`**: This is the native pixel format for iOS display. Using it avoids format conversion overhead. It provides 8 bits per channel (32 bits per pixel), which is sufficient for V1. It matches `CGBitmapInfo` for efficient CPU↔GPU transfer.

### 7.3 Pipeline State Caching

```swift
func getOrCreatePipeline(functionName: String) throws -> MTLComputePipelineState {
    if let cached = computePipelines[functionName] {
        return cached
    }
    guard let function = context.library.makeFunction(name: functionName) else {
        throw MetalError.functionNotFound(functionName)
    }
    let pipeline = try context.device.makeComputePipelineState(function: function)
    computePipelines[functionName] = pipeline
    return pipeline
}
```

**Why cache**: `makeComputePipelineState` compiles the shader. This is expensive (can take milliseconds). Caching ensures it happens only once per shader function.

### 7.4 Sampler Configuration

```swift
func makeSampler(filter: MTLSamplerMinMagFilter) -> MTLSamplerState? {
    let descriptor = MTLSamplerDescriptor()
    descriptor.minFilter = filter
    descriptor.magFilter = filter
    descriptor.sAddressMode = .clampToEdge
    descriptor.tAddressMode = .clampToEdge
    return context.device.makeSamplerState(descriptor: descriptor)
}
```

- **Nearest sampler**: Used for pixel-exact operations (adjustments, grayscale, invert)
- **Linear sampler**: Used for operations that resample (pixelation, distortion, Gaussian blur)
- **Address mode `.clampToEdge`**: Prevents artifacts at image boundaries by clamping out-of-bounds UV coordinates to the edge pixel

### 7.5 Command Buffer Usage Pattern

For each pipeline execution:

```swift
func processPipeline(_ pipeline: ProcessingPipeline, 
                     source: MTLTexture) async throws -> (MTLTexture, PerformanceMetrics) {
    guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
        throw MetalError.commandBufferCreationFailed
    }
    
    var currentSource = source
    var metrics = PerformanceMetrics()
    metrics.imageWidth = source.width
    metrics.imageHeight = source.height
    metrics.pixelCount = source.width * source.height
    
    let startTime = CACurrentMediaTime()
    var passCount = 0
    
    for node in pipeline.enabledNodes {
        let destination = texturePool.acquire(
            device: context.device,
            width: source.width,
            height: source.height
        )!
        
        try encodeOperation(node, source: currentSource, destination: destination, 
                           commandBuffer: commandBuffer)
        
        if currentSource !== source {
            texturePool.release(currentSource) // Return intermediate texture
        }
        currentSource = destination
        passCount += 1
    }
    
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted() // Called from background context
    
    let endTime = CACurrentMediaTime()
    metrics.gpuTimeMs = (endTime - startTime) * 1000.0
    metrics.passCount = passCount
    
    return (currentSource, metrics)
}
```

**Critical note on `waitUntilCompleted`**: This blocks the calling thread. It must NEVER be called on the main thread. It is called from within an `async` context that Swift concurrency schedules on a background thread. For V1, this is the simplest correct approach. An alternative (using `commandBuffer.addCompletedHandler`) adds complexity without meaningful benefit since we need the result texture before continuing.

### 7.6 Threadgroup Configuration

For compute shaders, threads are dispatched in 2D grids:

```swift
func dispatchThreads(encoder: MTLComputeCommandEncoder,
                     pipeline: MTLComputePipelineState,
                     width: Int, height: Int) {
    let threadgroupSize = MTLSize(
        width: min(pipeline.threadExecutionWidth, width),
        height: min(pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth, height),
        depth: 1
    )
    let threadgroupCount = MTLSize(
        width: (width + threadgroupSize.width - 1) / threadgroupSize.width,
        height: (height + threadgroupSize.height - 1) / threadgroupSize.height,
        depth: 1
    )
    
    // Use dispatchThreadgroups (not dispatchThreads) for iPhone 11 compatibility
    encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
}
```

**Why `dispatchThreadgroups` instead of `dispatchThreads`**: `dispatchThreads` (non-uniform threadgroup sizes) requires Metal GPU Family Apple 4+. iPhone 11 (A13) supports Apple GPU Family 6, so `dispatchThreads` IS available. However, `dispatchThreadgroups` is universally supported and is the safer choice. When using `dispatchThreadgroups`, shaders must include boundary checks:

```metal
if (gid.x >= outputWidth || gid.y >= outputHeight) return;
```

**Threadgroup size strategy**: Use `pipeline.threadExecutionWidth` (typically 32 on Apple GPUs) for width, and divide `maxTotalThreadsPerThreadgroup` by that for height. This gives optimal occupancy. Typical result on iPhone 11: `MTLSize(32, 32, 1)` = 1024 threads per threadgroup.

---

## 8. Shader Architecture

### 8.1 Shared Header: `ShaderTypes.h`

This header is included in both Swift (via bridging) and Metal:

```metal
#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Adjustment parameters — matches Swift struct layout
struct AdjustmentParams {
    float brightness;   // [-1.0, 1.0], default 0.0
    float contrast;     // [0.0, 4.0], default 1.0
    float exposure;     // [-5.0, 5.0], default 0.0
    float saturation;   // [0.0, 3.0], default 1.0
    float temperature;  // [-1.0, 1.0], default 0.0
    float tint;         // [-1.0, 1.0], default 0.0
    float gamma;        // [0.1, 5.0], default 1.0
    float _padding;     // Pad to 32 bytes (8 × 4)
};

// Convolution kernel parameters
struct ConvolutionParams {
    float kernel[9];       // 3×3 kernel, row-major
    float divisor;         // Normalization divisor
    float bias;            // Added after division
    float strength;        // Blend factor [0.0, 1.0]
    uint32_t texWidth;     // Texture width for boundary check
    uint32_t texHeight;    // Texture height for boundary check
    float _padding[2];     // Pad to 64 bytes
};

// Gaussian blur parameters
struct GaussianBlurParams {
    float weights[127];    // Max radius 63 → 127 weights
    int radius;            // Kernel half-size
    uint32_t texWidth;
    uint32_t texHeight;
    int isHorizontal;      // 0 = vertical, 1 = horizontal
    float _padding[3];
};

// Effect parameters (for simple effects)
struct EffectParams {
    float strength;        // General strength/amount [0.0, 1.0]
    float param1;          // Effect-specific
    float param2;          // Effect-specific
    float param3;          // Effect-specific
    uint32_t texWidth;
    uint32_t texHeight;
    float _padding[2];
};

// Distortion parameters
struct DistortionParams {
    float centerX;         // Normalized center [0.0, 1.0]
    float centerY;
    float radius;          // Effect radius in normalized coords
    float strength;        // Distortion strength
    float frequency;       // For ripple: wave frequency
    float phase;           // For ripple: wave phase
    uint32_t texWidth;
    uint32_t texHeight;
};

#endif
```

### 8.2 Memory Alignment Rules

Metal requires specific alignment:
- `float`: 4-byte aligned
- `float2`/`simd_float2`: 8-byte aligned
- `float3`/`simd_float3`: 16-byte aligned (NOT 12!)
- `float4`/`simd_float4`: 16-byte aligned
- Struct total size: Should be multiple of largest alignment in struct

**Swift counterpart must match exactly**:

```swift
struct AdjustmentParams {
    var brightness: Float = 0.0
    var contrast: Float = 1.0
    var exposure: Float = 0.0
    var saturation: Float = 1.0
    var temperature: Float = 0.0
    var tint: Float = 0.0
    var gamma: Float = 1.0
    var _padding: Float = 0.0
}
```

**Verification**: `MemoryLayout<AdjustmentParams>.size` must equal `sizeof(AdjustmentParams)` in Metal (32 bytes). Gemini should add an assertion in debug builds:

```swift
assert(MemoryLayout<AdjustmentParams>.size == 32, 
       "AdjustmentParams size mismatch with Metal")
```

### 8.3 Shader Naming Convention

All compute kernel functions follow this naming:

| Operation | Metal Function Name |
|---|---|
| Adjustments (combined) | `adjustments_kernel` |
| Grayscale | `grayscale_kernel` |
| Invert | `invert_kernel` |
| Gaussian Blur (H) | `gaussian_blur_h_kernel` |
| Gaussian Blur (V) | `gaussian_blur_v_kernel` |
| Sharpen | `convolution_kernel` (reused) |
| Sobel Edge | `sobel_kernel` |
| Pixelation | `pixelate_kernel` |
| Ripple | `ripple_kernel` |
| Swirl | `swirl_kernel` |
| Convolution (generic) | `convolution_kernel` |

### 8.4 Shader File Organization

All Metal shaders go into a single file `Shaders.metal` for V1 simplicity. The file is organized with `#pragma mark` sections:

```metal
#include <metal_stdlib>
#include "ShaderTypes.h"
using namespace metal;

#pragma mark - Utility Functions
// sRGB ↔ linear, luminance, clamp helpers

#pragma mark - Adjustments
// adjustments_kernel

#pragma mark - Basic Effects
// grayscale_kernel, invert_kernel

#pragma mark - Gaussian Blur
// gaussian_blur_h_kernel, gaussian_blur_v_kernel

#pragma mark - Convolution
// convolution_kernel

#pragma mark - Sobel
// sobel_kernel

#pragma mark - Pixelation
// pixelate_kernel

#pragma mark - Distortion
// ripple_kernel, swirl_kernel
```

### 8.5 Compute vs Fragment Shader Decision Table

| Operation | Shader Type | Reason |
|---|---|---|
| Brightness | **Compute** | Per-pixel independent operation; compute shaders avoid render-pass overhead and don't need vertex processing |
| Contrast | **Compute** | Same as brightness — per-pixel, no geometry needed |
| Exposure | **Compute** | Same rationale |
| Saturation | **Compute** | Same rationale |
| Temperature | **Compute** | Same rationale |
| Tint | **Compute** | Same rationale |
| Gamma | **Compute** | Same rationale |
| All adjustments combined | **Compute** | Combined into single kernel to minimize passes |
| Grayscale | **Compute** | Per-pixel color transformation |
| Invert | **Compute** | Per-pixel color transformation |
| Gaussian Blur | **Compute** | Requires reading multiple texels per output pixel; compute shader threadgroup memory can cache rows/columns for better performance |
| Sharpen (convolution) | **Compute** | 3×3 neighborhood sampling; same convolution kernel |
| Sobel Edge Detection | **Compute** | 3×3 neighborhood sampling on two kernels; compute avoids render pass overhead |
| Pixelation | **Compute** | Simple UV remapping per pixel |
| Ripple Distortion | **Compute** | UV coordinate transformation per pixel |
| Swirl Distortion | **Compute** | UV coordinate transformation per pixel |
| Convolution (generic) | **Compute** | 3×3 neighborhood sampling with dynamic kernel |

**Why ALL compute (no fragment shaders)**: For image processing where every pixel is processed independently (or with known neighborhood), compute shaders are strictly superior because:
1. No render pass setup (no `MTLRenderPassDescriptor`, no vertex buffer, no viewport)
2. No full-screen quad geometry needed
3. Direct 2D thread dispatch maps naturally to image dimensions
4. Access to threadgroup memory for neighborhood caching
5. Simpler code — just encode and dispatch

Fragment shaders are better for real-time rendering with geometry, blending, and rasterization — none of which apply here.

---

## 9. Filter-by-Filter Implementation

### 9.1 Combined Adjustments Kernel

**Why combined**: All 7 adjustments (brightness, contrast, exposure, saturation, temperature, tint, gamma) operate per-pixel with no neighborhood dependency. Combining them into a single kernel avoids 7 separate dispatch calls and 7 texture read/write cycles.

**Color space assumption**: All processing operates in sRGB space (the native space of `.bgra8Unorm` textures). This is acceptable for V1. The texture stores sRGB values in [0,1] range as linear samples because `bgra8Unorm` does NOT have automatic sRGB conversion (unlike `bgra8Unorm_srgb`). For V1, we treat pixel values as linear and apply transformations directly.

**Mathematical models**:

#### Brightness
```
output.rgb = input.rgb + brightness
```
- `brightness` ∈ [-1.0, 1.0], default 0.0
- Additive offset to all channels equally
- Slider: -100% to +100%, step 1%

#### Contrast
```
output.rgb = (input.rgb - 0.5) × contrast + 0.5
```
- `contrast` ∈ [0.0, 4.0], default 1.0
- Scales deviation from mid-gray
- At 0.0: all pixels become 0.5 gray
- At 1.0: no change
- At 4.0: extreme contrast
- Slider: 0% to 400%, default 100%

#### Exposure
```
output.rgb = input.rgb × pow(2.0, exposure)
```
- `exposure` ∈ [-5.0, 5.0], default 0.0
- Simulates photographic exposure stops
- Each +1.0 doubles brightness
- Slider: -5.0 to +5.0 EV, step 0.1

#### Saturation
```
float lum = dot(input.rgb, float3(0.2126, 0.7152, 0.0722));
output.rgb = mix(float3(lum), input.rgb, saturation);
```
- `saturation` ∈ [0.0, 3.0], default 1.0
- Luminance weights: ITU-R BT.709
- At 0.0: grayscale
- At 1.0: no change
- At 3.0: oversaturated
- Slider: 0% to 300%, default 100%

#### Temperature
```
// Simplified white-balance shift
output.r = input.r + temperature × 0.1;
output.g = input.g;
output.b = input.b - temperature × 0.1;
```
- `temperature` ∈ [-1.0, 1.0], default 0.0
- Positive: warm (add red, subtract blue)
- Negative: cool (add blue, subtract red)
- Slider: -100% to +100%

#### Tint
```
output.r = input.r;
output.g = input.g + tint × 0.1;
output.b = input.b;
```
- `tint` ∈ [-1.0, 1.0], default 0.0
- Positive: green shift
- Negative: magenta shift (via green reduction)
- Slider: -100% to +100%

#### Gamma
```
output.rgb = pow(input.rgb, float3(1.0 / gamma));
```
- `gamma` ∈ [0.1, 5.0], default 1.0
- Standard gamma correction
- Values < 1.0: darken midtones
- Values > 1.0: brighten midtones
- Slider: 0.1 to 5.0, step 0.1

#### Complete Metal Shader

```metal
kernel void adjustments_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant AdjustmentParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;
    
    float4 color = inTexture.read(gid);
    float3 rgb = color.rgb;
    
    // 1. Exposure (multiplicative, apply first)
    rgb *= pow(2.0, params.exposure);
    
    // 2. Brightness (additive)
    rgb += params.brightness;
    
    // 3. Contrast (scale around 0.5)
    rgb = (rgb - 0.5) * params.contrast + 0.5;
    
    // 4. Temperature
    rgb.r += params.temperature * 0.1;
    rgb.b -= params.temperature * 0.1;
    
    // 5. Tint
    rgb.g += params.tint * 0.1;
    
    // 6. Saturation
    float lum = dot(rgb, float3(0.2126, 0.7152, 0.0722));
    rgb = mix(float3(lum), rgb, params.saturation);
    
    // 7. Gamma
    rgb = pow(clamp(rgb, 0.0, 1.0), float3(1.0 / params.gamma));
    
    outTexture.write(float4(rgb, color.a), gid);
}
```

**Application order rationale**: Exposure first (multiplicative scaling), then brightness (additive offset), then contrast (pivot around midpoint), then color corrections (temperature, tint), then saturation (which depends on accurate color values), then gamma (final tone curve). This order minimizes artifacts from clamping.

#### Swift Encoding

```swift
func encodeAdjustments(source: MTLTexture, destination: MTLTexture,
                       params: AdjustmentParams,
                       commandBuffer: MTLCommandBuffer) throws {
    let pipeline = try getOrCreatePipeline(functionName: "adjustments_kernel")
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
        throw MetalError.encoderCreationFailed
    }
    
    encoder.setComputePipelineState(pipeline)
    encoder.setTexture(source, index: 0)
    encoder.setTexture(destination, index: 1)
    
    var params = params
    encoder.setBytes(&params, length: MemoryLayout<AdjustmentParams>.size, index: 0)
    
    dispatchThreads(encoder: encoder, pipeline: pipeline,
                    width: source.width, height: source.height)
    encoder.endEncoding()
}
```

**Why `setBytes` instead of `MTLBuffer`**: For small parameter structs (<4KB), `setBytes` avoids the overhead of creating and managing `MTLBuffer` objects. Metal internally manages a ring buffer for these small uploads. Our largest struct (GaussianBlurParams with 127 weights) is ~520 bytes, well within the limit.

### 9.2 Grayscale

**Algorithm**: Convert RGB to luminance using ITU-R BT.709 coefficients.

```metal
kernel void grayscale_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;
    
    float4 color = inTexture.read(gid);
    float lum = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    outTexture.write(float4(lum, lum, lum, color.a), gid);
}
```

**Why BT.709**: These are the standard coefficients for sRGB and HDTV. Using equal weights (0.333) would produce incorrect perceived brightness.

### 9.3 Invert

**Algorithm**: `output = 1.0 - input` for RGB channels. Alpha preserved.

```metal
kernel void invert_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;
    
    float4 color = inTexture.read(gid);
    outTexture.write(float4(1.0 - color.rgb, color.a), gid);
}
```

### 9.4 Gaussian Blur — Major GPU Demonstration

#### Theory

A 2D Gaussian blur with kernel radius `r` and standard deviation `σ` would require `(2r+1)²` texture reads per pixel. For `r=10`, that's 441 reads per pixel — very expensive.

**Separable decomposition**: A 2D Gaussian kernel is separable into two 1D passes:
1. Horizontal pass: blur each row independently → intermediate texture
2. Vertical pass: blur each column of the intermediate → final texture

Each pass requires only `(2r+1)` reads per pixel. For `r=10`, that's 42 total reads instead of 441.

#### Gaussian Kernel Weights

Computed on CPU and passed to GPU:

```swift
func computeGaussianWeights(sigma: Float, radius: Int) -> [Float] {
    let size = radius * 2 + 1
    var weights = [Float](repeating: 0, count: size)
    var sum: Float = 0
    
    for i in 0..<size {
        let x = Float(i - radius)
        let w = exp(-(x * x) / (2.0 * sigma * sigma))
        weights[i] = w
        sum += w
    }
    
    // Normalize so weights sum to 1.0
    for i in 0..<size {
        weights[i] /= sum
    }
    
    return weights
}
```

#### Parameters

- `sigma` ∈ [0.1, 20.0], default 1.0
- `radius` = `ceil(sigma × 3)`, capped at 63 (giving max kernel size 127)
- Slider shows sigma value; radius is computed automatically
- Slider: 0.1 to 20.0, step 0.1

#### Metal Shaders

```metal
kernel void gaussian_blur_h_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant GaussianBlurParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= params.texWidth || gid.y >= params.texHeight) return;
    
    float4 sum = float4(0.0);
    int radius = params.radius;
    
    for (int i = -radius; i <= radius; i++) {
        int sampleX = clamp(int(gid.x) + i, 0, int(params.texWidth) - 1);
        float weight = params.weights[i + radius];
        sum += inTexture.read(uint2(sampleX, gid.y)) * weight;
    }
    
    outTexture.write(sum, gid);
}

kernel void gaussian_blur_v_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant GaussianBlurParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= params.texWidth || gid.y >= params.texHeight) return;
    
    float4 sum = float4(0.0);
    int radius = params.radius;
    
    for (int i = -radius; i <= radius; i++) {
        int sampleY = clamp(int(gid.y) + i, 0, int(params.texHeight) - 1);
        float weight = params.weights[i + radius];
        sum += inTexture.read(uint2(gid.x, sampleY)) * weight;
    }
    
    outTexture.write(sum, gid);
}
```

#### Two-Pass Encoding

```swift
func encodeGaussianBlur(source: MTLTexture, destination: MTLTexture,
                        sigma: Float, commandBuffer: MTLCommandBuffer) throws {
    let radius = min(Int(ceil(sigma * 3.0)), 63)
    let weights = computeGaussianWeights(sigma: sigma, radius: radius)
    
    var params = GaussianBlurParams()
    for (i, w) in weights.enumerated() where i < 127 {
        params.weights.i = w  // Set indexed — see note below
    }
    params.radius = Int32(radius)
    params.texWidth = UInt32(source.width)
    params.texHeight = UInt32(source.height)
    
    // Intermediate texture for horizontal pass output
    guard let intermediate = texturePool.acquire(
        device: context.device,
        width: source.width, height: source.height
    ) else { throw MetalError.textureCreationFailed }
    
    // Pass 1: Horizontal
    let hPipeline = try getOrCreatePipeline(functionName: "gaussian_blur_h_kernel")
    let hEncoder = commandBuffer.makeComputeCommandEncoder()!
    hEncoder.setComputePipelineState(hPipeline)
    hEncoder.setTexture(source, index: 0)
    hEncoder.setTexture(intermediate, index: 1)
    params.isHorizontal = 1
    hEncoder.setBytes(&params, length: MemoryLayout<GaussianBlurParams>.size, index: 0)
    dispatchThreads(encoder: hEncoder, pipeline: hPipeline,
                    width: source.width, height: source.height)
    hEncoder.endEncoding()
    
    // Pass 2: Vertical
    let vPipeline = try getOrCreatePipeline(functionName: "gaussian_blur_v_kernel")
    let vEncoder = commandBuffer.makeComputeCommandEncoder()!
    vEncoder.setComputePipelineState(vPipeline)
    vEncoder.setTexture(intermediate, index: 0)
    vEncoder.setTexture(destination, index: 1)
    params.isHorizontal = 0
    vEncoder.setBytes(&params, length: MemoryLayout<GaussianBlurParams>.size, index: 0)
    dispatchThreads(encoder: vEncoder, pipeline: vPipeline,
                    width: source.width, height: source.height)
    vEncoder.endEncoding()
    
    // Return intermediate texture to pool after command buffer completes
    commandBuffer.addCompletedHandler { [weak self] _ in
        self?.texturePool.release(intermediate)
    }
}
```

**Note on `GaussianBlurParams.weights`**: In Swift, a fixed-size C array `float weights[127]` maps to a tuple `(Float, Float, Float, ...)`. To set values, use `withUnsafeMutableBytes` on the params struct:

```swift
withUnsafeMutableBytes(of: &params.weights) { ptr in
    let floatPtr = ptr.bindMemory(to: Float.self)
    for (i, w) in weights.enumerated() {
        floatPtr[i] = w
    }
}
```

**Performance considerations**:
- For sigma > 5.0, consider down-sampling the texture, blurring at lower resolution, then up-sampling. This is a V2 optimization.
- Two command encoders in one command buffer is correct — Metal handles the dependency automatically.
- The `addCompletedHandler` for returning intermediate textures is essential to avoid premature reuse.

### 9.5 Sharpen — Convolution-Based

Uses the generic convolution kernel with a sharpening matrix:

```
Kernel:
[ 0, -1,  0]
[-1,  5, -1]
[ 0, -1,  0]

Divisor: 1.0
Bias: 0.0
```

This is an unsharp mask approximation. The center value (5) is identity (4) + edge emphasis (1). The negative neighbors subtract the local average, enhancing edges.

**Strength parameter**: Blend between original and sharpened:
```
output = mix(original, sharpened, strength)
```
- `strength` ∈ [0.0, 1.0], default 0.5
- At 0.0: no sharpening
- At 1.0: full sharpening

**Implementation**: Reuses `convolution_kernel` (see §9.8). No separate shader needed.

### 9.6 Sobel Edge Detection

**Algorithm**: Computes image gradient magnitude using two 3×3 kernels.

Sobel X (horizontal edges):
```
[-1, 0, 1]
[-2, 0, 2]
[-1, 0, 1]
```

Sobel Y (vertical edges):
```
[-1, -2, -1]
[ 0,  0,  0]
[ 1,  2,  1]
```

For each pixel:
```
Gx = sum of (pixel × Sobel_X_kernel)
Gy = sum of (pixel × Sobel_Y_kernel)
magnitude = sqrt(Gx² + Gy²)
output = clamp(magnitude × strength, 0.0, 1.0)
```

```metal
kernel void sobel_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant EffectParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= params.texWidth || gid.y >= params.texHeight) return;
    
    // Read 3×3 neighborhood (luminance only for edge detection)
    float samples[3][3];
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            uint2 pos = uint2(
                clamp(int(gid.x) + dx, 0, int(params.texWidth) - 1),
                clamp(int(gid.y) + dy, 0, int(params.texHeight) - 1)
            );
            float4 c = inTexture.read(pos);
            samples[dy + 1][dx + 1] = dot(c.rgb, float3(0.2126, 0.7152, 0.0722));
        }
    }
    
    // Sobel X
    float gx = -samples[0][0] + samples[0][2]
              -2.0*samples[1][0] + 2.0*samples[1][2]
              -samples[2][0] + samples[2][2];
    
    // Sobel Y
    float gy = -samples[0][0] - 2.0*samples[0][1] - samples[0][2]
              +samples[2][0] + 2.0*samples[2][1] + samples[2][2];
    
    float magnitude = sqrt(gx * gx + gy * gy);
    magnitude = clamp(magnitude * params.strength, 0.0, 1.0);
    
    float4 original = inTexture.read(gid);
    float4 edgeColor = float4(magnitude, magnitude, magnitude, original.a);
    
    // Blend: at strength 1.0, show pure edges; at 0.5, overlay on original
    float4 output = mix(original, edgeColor, params.param1); // param1 = blend mode
    outTexture.write(output, gid);
}
```

**Parameters**:
- `strength` ∈ [0.5, 5.0], default 1.0 — scales gradient magnitude
- `param1` (blend) ∈ [0.0, 1.0], default 1.0 — 0 = overlay on image, 1 = pure edges

### 9.7 Pixelation / Mosaic

**Algorithm**: Quantize UV coordinates to a block grid. Sample the center of each block.

```metal
kernel void pixelate_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant EffectParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= params.texWidth || gid.y >= params.texHeight) return;
    
    float blockSize = max(params.strength, 1.0); // Block size in pixels
    
    // Find the center of the block this pixel belongs to
    uint2 blockOrigin = uint2(
        uint(float(gid.x) / blockSize) * uint(blockSize),
        uint(float(gid.y) / blockSize) * uint(blockSize)
    );
    
    // Sample from block center
    uint2 samplePos = uint2(
        clamp(blockOrigin.x + uint(blockSize * 0.5), 0u, params.texWidth - 1),
        clamp(blockOrigin.y + uint(blockSize * 0.5), 0u, params.texHeight - 1)
    );
    
    float4 color = inTexture.read(samplePos);
    outTexture.write(color, gid);
}
```

**Parameters**:
- `blockSize` (via `strength`) ∈ [1.0, 100.0], default 10.0
- At 1.0: no pixelation (original image)
- At 100.0: very large blocks
- Slider: 1 to 100 pixels, step 1

### 9.8 Generic Convolution Kernel

This is the **reusable engine** for Sharpen, the Convolution Lab's built-in kernels, and custom 3×3 kernels.

```metal
kernel void convolution_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant ConvolutionParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= params.texWidth || gid.y >= params.texHeight) return;
    
    float4 sum = float4(0.0);
    int index = 0;
    
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            uint2 pos = uint2(
                clamp(int(gid.x) + dx, 0, int(params.texWidth) - 1),
                clamp(int(gid.y) + dy, 0, int(params.texHeight) - 1)
            );
            float4 sample = inTexture.read(pos);
            sum += sample * params.kernel[index];
            index++;
        }
    }
    
    // Normalize and add bias
    float4 result = sum / params.divisor + params.bias;
    result = clamp(result, 0.0, 1.0);
    result.a = inTexture.read(gid).a; // Preserve alpha
    
    // Blend with original based on strength
    float4 original = inTexture.read(gid);
    float4 output = mix(original, result, params.strength);
    outTexture.write(output, gid);
}
```

**Boundary handling**: `clamp` to edge — pixels at borders replicate the edge pixel rather than reading garbage or wrapping.

**Built-in kernels for Convolution Lab**:

| Name | Kernel | Divisor | Bias |
|------|--------|---------|------|
| Blur | `[1,1,1, 1,1,1, 1,1,1]` | 9.0 | 0.0 |
| Sharpen | `[0,-1,0, -1,5,-1, 0,-1,0]` | 1.0 | 0.0 |
| Edge Detection | `[-1,-1,-1, -1,8,-1, -1,-1,-1]` | 1.0 | 0.0 |
| Emboss | `[-2,-1,0, -1,1,1, 0,1,2]` | 1.0 | 0.5 |

### 9.9 Distortion — Ripple

**Algorithm**: Apply sinusoidal displacement to UV coordinates based on distance from center.

```metal
kernel void ripple_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant DistortionParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= params.texWidth || gid.y >= params.texHeight) return;
    
    // Normalized coordinates [0, 1]
    float2 uv = float2(float(gid.x) / float(params.texWidth),
                        float(gid.y) / float(params.texHeight));
    
    float2 center = float2(params.centerX, params.centerY);
    float2 delta = uv - center;
    float dist = length(delta);
    
    // Apply ripple only within radius
    if (dist < params.radius && dist > 0.001) {
        float displacement = sin(dist * params.frequency - params.phase) * params.strength;
        float2 direction = normalize(delta);
        uv += direction * displacement * 0.05;
    }
    
    // Clamp UV to valid range
    uv = clamp(uv, float2(0.0), float2(1.0));
    
    // Convert back to pixel coordinates and read
    uint2 samplePos = uint2(
        clamp(uint(uv.x * float(params.texWidth)), 0u, params.texWidth - 1),
        clamp(uint(uv.y * float(params.texHeight)), 0u, params.texHeight - 1)
    );
    
    outTexture.write(inTexture.read(samplePos), gid);
}
```

**Parameters**:
- `centerX`, `centerY`: 0.5, 0.5 (center of image)
- `radius` ∈ [0.1, 1.0], default 0.5
- `strength` ∈ [0.0, 1.0], default 0.3
- `frequency` ∈ [5.0, 100.0], default 30.0
- `phase` ∈ [0.0, 6.28], default 0.0

### 9.10 Distortion — Swirl

**Algorithm**: Rotate UV coordinates around center by an angle proportional to distance.

```metal
kernel void swirl_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant DistortionParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= params.texWidth || gid.y >= params.texHeight) return;
    
    float2 uv = float2(float(gid.x) / float(params.texWidth),
                        float(gid.y) / float(params.texHeight));
    
    float2 center = float2(params.centerX, params.centerY);
    float2 delta = uv - center;
    float dist = length(delta);
    
    if (dist < params.radius) {
        // Angle decreases with distance from center (stronger swirl at center)
        float normalizedDist = dist / params.radius;
        float angle = params.strength * (1.0 - normalizedDist) * 6.2832; // Max 2π rotation
        
        // Rotate delta by angle
        float cosA = cos(angle);
        float sinA = sin(angle);
        float2 rotated = float2(
            delta.x * cosA - delta.y * sinA,
            delta.x * sinA + delta.y * cosA
        );
        
        uv = center + rotated;
    }
    
    uv = clamp(uv, float2(0.0), float2(1.0));
    uint2 samplePos = uint2(
        clamp(uint(uv.x * float(params.texWidth)), 0u, params.texWidth - 1),
        clamp(uint(uv.y * float(params.texHeight)), 0u, params.texHeight - 1)
    );
    
    outTexture.write(inTexture.read(samplePos), gid);
}
```

**Parameters**:
- `centerX`, `centerY`: 0.5, 0.5
- `radius` ∈ [0.1, 1.0], default 0.5
- `strength` ∈ [-1.0, 1.0], default 0.5 (negative = counter-clockwise)

---

## 10. Convolution Lab — Signature Feature

### 10.1 SwiftUI Design

The Convolution Lab is a dedicated section within the Effects tab. It contains:

1. **Built-in Kernel Picker**: Horizontal scroll of 4 preset buttons (Blur, Sharpen, Edge, Emboss)
2. **3×3 Kernel Grid**: A 3×3 grid of `TextField` inputs, each accepting a floating-point value
3. **Divisor Field**: Single `TextField` for the normalization divisor
4. **Bias Field**: Single `TextField` for the post-normalization bias
5. **Strength Slider**: Controls blend with original [0.0, 1.0]
6. **Apply Button**: Adds the convolution to the pipeline (or updates if already present)
7. **Reset Button**: Resets kernel to identity `[0,0,0, 0,1,0, 0,0,0]`

### 10.2 Kernel Data Model

```swift
struct ConvolutionKernel: Codable, Equatable, Sendable {
    var values: [Float]  // Exactly 9 elements, row-major
    var divisor: Float
    var bias: Float
    var name: String
    
    static let identity = ConvolutionKernel(
        values: [0,0,0, 0,1,0, 0,0,0], divisor: 1.0, bias: 0.0, name: "Identity"
    )
    
    static let blur = ConvolutionKernel(
        values: [1,1,1, 1,1,1, 1,1,1], divisor: 9.0, bias: 0.0, name: "Blur"
    )
    
    static let sharpen = ConvolutionKernel(
        values: [0,-1,0, -1,5,-1, 0,-1,0], divisor: 1.0, bias: 0.0, name: "Sharpen"
    )
    
    static let edgeDetect = ConvolutionKernel(
        values: [-1,-1,-1, -1,8,-1, -1,-1,-1], divisor: 1.0, bias: 0.0, name: "Edge Detection"
    )
    
    static let emboss = ConvolutionKernel(
        values: [-2,-1,0, -1,1,1, 0,1,2], divisor: 1.0, bias: 0.5, name: "Emboss"
    )
}
```

### 10.3 Validation Rules

- `values` must have exactly 9 elements
- Each value must be a valid `Float` (reject non-numeric input)
- `divisor` must not be zero (show error: "Divisor cannot be zero")
- `divisor` should default to sum of positive kernel values if user doesn't specify
- `bias` can be any float, typically [0.0, 1.0]
- Each `TextField` shows 2 decimal places

### 10.4 How the Same Engine Serves Multiple Features

The `convolution_kernel` shader is used for:
1. **Sharpen effect** (in Effects tab) → passes the sharpen kernel
2. **Convolution Lab built-in kernels** → passes the selected preset kernel
3. **Custom kernels** → passes user-entered values

All three use the same Swift encoding function:

```swift
func encodeConvolution(source: MTLTexture, destination: MTLTexture,
                       kernel: ConvolutionKernel, strength: Float,
                       commandBuffer: MTLCommandBuffer) throws {
    let pipeline = try getOrCreatePipeline(functionName: "convolution_kernel")
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
        throw MetalError.encoderCreationFailed
    }
    
    var params = ConvolutionParams()
    for (i, v) in kernel.values.enumerated() where i < 9 {
        withUnsafeMutableBytes(of: &params.kernel) { ptr in
            ptr.storeBytes(of: v, toByteOffset: i * MemoryLayout<Float>.size, as: Float.self)
        }
    }
    params.divisor = kernel.divisor
    params.bias = kernel.bias
    params.strength = strength
    params.texWidth = UInt32(source.width)
    params.texHeight = UInt32(source.height)
    
    encoder.setComputePipelineState(pipeline)
    encoder.setTexture(source, index: 0)
    encoder.setTexture(destination, index: 1)
    encoder.setBytes(&params, length: MemoryLayout<ConvolutionParams>.size, index: 0)
    
    dispatchThreads(encoder: encoder, pipeline: pipeline,
                    width: source.width, height: source.height)
    encoder.endEncoding()
}
```

---

## 11. Processing Pipeline

### 11.1 Pipeline Data Model

```swift
struct ProcessingPipeline: Codable, Equatable, Sendable {
    var nodes: [PipelineNode] = []
    
    var enabledNodes: [PipelineNode] {
        nodes.filter { $0.isEnabled }
    }
    
    mutating func addNode(_ node: PipelineNode) {
        nodes.append(node)
    }
    
    mutating func removeNode(at index: Int) {
        nodes.remove(at: index)
    }
    
    mutating func moveNode(from: IndexSet, to: Int) {
        nodes.move(fromOffsets: from, toOffset: to)
    }
    
    mutating func toggleNode(at index: Int) {
        nodes[index].isEnabled.toggle()
    }
    
    mutating func reset() {
        nodes.removeAll()
    }
}

struct PipelineNode: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var operation: ProcessingOperation
    var isEnabled: Bool
    
    init(operation: ProcessingOperation, isEnabled: Bool = true) {
        self.id = UUID()
        self.operation = operation
        self.isEnabled = isEnabled
    }
}

enum ProcessingOperation: Codable, Equatable, Sendable {
    case adjustments(AdjustmentParams)
    case grayscale
    case invert
    case gaussianBlur(sigma: Float)
    case sharpen(strength: Float)
    case sobelEdge(strength: Float, blend: Float)
    case pixelate(blockSize: Float)
    case ripple(RippleParams)
    case swirl(SwirlParams)
    case convolution(ConvolutionKernel, strength: Float)
    
    var displayName: String {
        switch self {
        case .adjustments: return "Adjustments"
        case .grayscale: return "Grayscale"
        case .invert: return "Invert"
        case .gaussianBlur: return "Gaussian Blur"
        case .sharpen: return "Sharpen"
        case .sobelEdge: return "Sobel Edge"
        case .pixelate: return "Pixelation"
        case .ripple: return "Ripple"
        case .swirl: return "Swirl"
        case .convolution: return "Convolution"
        }
    }
    
    var category: OperationCategory {
        switch self {
        case .adjustments: return .adjustment
        case .grayscale, .invert: return .basic
        case .gaussianBlur: return .blur
        case .sharpen: return .sharpen
        case .sobelEdge: return .edge
        case .pixelate: return .pixelation
        case .ripple, .swirl: return .distortion
        case .convolution: return .convolution
        }
    }
}

enum OperationCategory: String, CaseIterable {
    case adjustment = "Adjustments"
    case basic = "Basic"
    case blur = "Blur"
    case sharpen = "Sharpen"
    case edge = "Edge Detection"
    case pixelation = "Pixelation"
    case distortion = "Distortion"
    case convolution = "Convolution Lab"
}
```

### 11.2 Pipeline Execution

The `MetalProcessor.process()` method iterates through `pipeline.enabledNodes` sequentially, ping-ponging between textures:

```
Source → [Node 1] → Tex A → [Node 2] → Tex B → [Node 3] → Tex A → ... → Output
```

Each node encodes its compute shader into the SAME command buffer. This means all operations are submitted as a single GPU workload, and Metal handles inter-pass synchronization automatically (a compute encoder's writes are visible to the next compute encoder in the same command buffer).

### 11.3 When to Combine vs Separate Passes

**COMBINE into single pass**:
- All 7 adjustments → single `adjustments_kernel` dispatch (already implemented this way)

**KEEP SEPARATE passes**:
- Gaussian blur requires TWO passes (horizontal + vertical) — cannot be combined with other operations
- Convolution operations that sample neighborhoods cannot be combined with per-pixel operations without architectural complexity
- Distortions that remap UV coordinates cannot be combined with convolutions

**Rule**: In V1, every pipeline node gets its own pass (except the 7 adjustments which are always combined). This is simpler, correct, and the per-pass overhead is negligible compared to actual shader execution time on images.

### 11.4 Pipeline UI Architecture

```swift
struct PipelineView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddOperation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mini preview
                if let image = appState.displayImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 150)
                        .padding()
                }
                
                // Pipeline list
                List {
                    ForEach(Array(appState.pipeline.nodes.enumerated()), id: \.element.id) { index, node in
                        PipelineNodeRow(node: node, index: index)
                    }
                    .onMove { appState.movePipelineNode(from: $0, to: $1) }
                    .onDelete { appState.removePipelineNodes(at: $0) }
                }
                .listStyle(.insetGrouped)
                
                // Bottom toolbar
                HStack {
                    Button("Add Operation") { showAddOperation = true }
                    Spacer()
                    Button("Reset Pipeline", role: .destructive) { appState.resetPipeline() }
                }
                .padding()
            }
            .navigationTitle("Pipeline")
            .toolbar { EditButton() }
            .sheet(isPresented: $showAddOperation) {
                AddOperationSheet()
            }
        }
    }
}
```

---

## 12. Before / After Comparison

### 12.1 Comparison Modes

```swift
enum ComparisonMode: String, CaseIterable {
    case original = "Original"
    case processed = "Processed"
    case sideBySide = "Side by Side"
    case split = "Split"
}
```

### 12.2 Implementation

- **Original**: Display `UIImage` from `originalTexture` (computed once when image is loaded)
- **Processed**: Display `UIImage` from `processedTexture` (updated after each pipeline run)
- **Side-by-side**: `HStack` with two `Image` views, each taking 50% width
- **Split**: Single canvas with draggable vertical divider

#### Split Comparison

```swift
struct SplitComparisonView: View {
    let originalImage: UIImage
    let processedImage: UIImage
    @Binding var splitPosition: CGFloat // [0.0, 1.0]
    @GestureState private var dragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let dividerX = (splitPosition + dragOffset) * geo.size.width
            
            ZStack {
                // Processed image (full)
                Image(uiImage: processedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                // Original image (clipped to left of divider)
                Image(uiImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(
                        Rectangle()
                            .size(width: dividerX, height: geo.size.height)
                    )
                
                // Divider line
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 3)
                    .position(x: dividerX, y: geo.size.height / 2)
                    .shadow(radius: 2)
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width / geo.size.width
                            }
                            .onEnded { value in
                                splitPosition += value.translation.width / geo.size.width
                                splitPosition = max(0.05, min(0.95, splitPosition))
                            }
                    )
            }
        }
    }
}
```

**Avoiding unnecessary texture copies**: The `originalImage` and `processedImage` are `UIImage` objects converted from textures. They are computed only when:
- `originalImage`: Once when the image is loaded
- `processedImage`: Only when the pipeline is re-executed

The comparison modes do NOT re-render Metal textures — they display cached `UIImage` objects. This is efficient because `UIImage` backed by `CGImage` is reference-counted.

---

## 13. GPU Performance Dashboard

### 13.1 Metrics Data Model

```swift
struct PerformanceMetrics: Sendable {
    var imageWidth: Int = 0
    var imageHeight: Int = 0
    var pixelCount: Int = 0
    var currentEffectName: String = ""
    var gpuTimeMs: Double = 0.0
    var passCount: Int = 0
    var frameTimeMs: Double = 0.0  // Total time including Swift overhead
    var lastUpdateTimestamp: Date = Date()
    
    var resolution: String {
        "\(imageWidth) × \(imageHeight)"
    }
    
    var megapixels: Double {
        Double(pixelCount) / 1_000_000.0
    }
}
```

### 13.2 How Each Metric Is Measured

| Metric | Measurement Method | API |
|---|---|---|
| Image resolution | `texture.width`, `texture.height` | Metal API |
| Pixel count | `width × height` | Arithmetic |
| Current effect | Name from last pipeline node | App state |
| GPU processing time | `CACurrentMediaTime()` before `commandBuffer.commit()` and after `commandBuffer.waitUntilCompleted()` | `CACurrentMediaTime` + Metal sync |
| GPU passes | Count of compute encoders created | Counter in processor |
| Frame time | `CACurrentMediaTime()` around entire `process()` call (includes Swift overhead) | `CACurrentMediaTime` |

> [!IMPORTANT]
> **What we do NOT display**:
> - GPU clock speed (not available via public API)
> - GPU utilization percentage (requires Xcode GPU profiler instruments, not accessible at runtime)
> - GPU memory usage per texture (not available via public API — only `device.currentAllocatedSize` exists, which is total)
> - Theoretical TFLOPS
> - Shader compilation time (measured once, not meaningful for runtime)
>
> Only runtime-measurable metrics are shown. Never fabricate statistics.

### 13.3 Timing Accuracy

`CACurrentMediaTime()` returns Mach absolute time with nanosecond precision. For GPU timing:

```swift
let startTime = CACurrentMediaTime()
commandBuffer.commit()
commandBuffer.waitUntilCompleted()
let endTime = CACurrentMediaTime()
let gpuTimeMs = (endTime - startTime) * 1000.0
```

**Caveat**: This measures wall-clock time from submission to completion, which includes:
- Command buffer scheduling overhead
- Actual GPU execution
- Any GPU queue contention

It does NOT separate "GPU only" time from "waiting in queue" time. For V1, this is acceptable and honestly reported as "GPU processing time (submission to completion)".

For more precise GPU-only timing, Metal offers `MTLCounterSampleBuffer` (GPU timestamp queries), but this is complex and a V2 feature.

### 13.4 Dashboard UI

```swift
struct GPUDashboardView: View {
    let metrics: PerformanceMetrics
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            MetricCard(title: "Resolution", value: metrics.resolution, icon: "rectangle.split.3x3")
            MetricCard(title: "Pixels", value: String(format: "%.1f MP", metrics.megapixels), icon: "square.grid.3x3")
            MetricCard(title: "GPU Time", value: String(format: "%.2f ms", metrics.gpuTimeMs), icon: "cpu")
            MetricCard(title: "Passes", value: "\(metrics.passCount)", icon: "arrow.triangle.2.circlepath")
            MetricCard(title: "Frame Time", value: String(format: "%.2f ms", metrics.frameTimeMs), icon: "clock")
            MetricCard(title: "Effect", value: metrics.currentEffectName.isEmpty ? "—" : metrics.currentEffectName, icon: "wand.and.stars")
        }
        .padding()
    }
}
```

---

## 14. CPU vs GPU Benchmark

### 14.1 Benchmark Engine

```swift
@MainActor
final class BenchmarkEngine {
    let metalProcessor: MetalProcessor
    
    struct BenchmarkConfig {
        let operation: ProcessingOperation
        let resolutions: [(Int, Int)] = [(512,512), (1024,1024), (2048,2048), (4096,4096)]
        let warmupRuns: Int = 3
        let measurementRuns: Int = 10
    }
    
    func runBenchmark(config: BenchmarkConfig) async -> [BenchmarkResult]
}
```

### 14.2 Benchmark Procedure

For each resolution:

1. **Generate test texture**: Create a `MTLTexture` of the target resolution filled with gradient data (not blank — representative workload).

2. **GPU Warm-up**: Run the operation `warmupRuns` (3) times. Discard results. This ensures:
   - Pipeline state is compiled and cached
   - GPU caches are populated
   - Driver optimizations are applied

3. **GPU Measurement**: Run the operation `measurementRuns` (10) times:
   ```swift
   var gpuTimes: [Double] = []
   for _ in 0..<config.measurementRuns {
       let start = CACurrentMediaTime()
       commandBuffer.commit()
       commandBuffer.waitUntilCompleted()
       let end = CACurrentMediaTime()
       gpuTimes.append((end - start) * 1000.0)
   }
   ```

4. **CPU Measurement** (for applicable operations):
   - Implement a CPU-side version of the same operation using `vImage` or manual pixel iteration
   - Use the same warm-up + measurement protocol
   ```swift
   var cpuTimes: [Double] = []
   for _ in 0..<config.measurementRuns {
       let start = CACurrentMediaTime()
       // CPU processing
       let end = CACurrentMediaTime()
       cpuTimes.append((end - start) * 1000.0)
   }
   ```

5. **Outlier handling**: Remove the fastest and slowest run from each set, average the remaining 8.

6. **Compute speedup**: `speedup = cpuAverage / gpuAverage`

### 14.3 CPU Reference Implementations

Only implement CPU versions for operations where the comparison is meaningful and fair:

| Operation | CPU Implementation | Fair Comparison? |
|---|---|---|
| Grayscale | Manual pixel loop over `UnsafeMutablePointer<UInt8>` | Yes |
| Gaussian Blur | `vImage` or manual convolution loop | Yes (but vImage uses SIMD) |
| Convolution 3×3 | Manual nested loop over pixel buffer | Yes |
| Invert | Manual pixel loop | Yes |
| Adjustments | Manual pixel loop applying same math | Yes |

**vImage consideration**: Using `vImageConvolve_ARGB8888` for the CPU blur benchmark would be a fairer comparison than a naive manual loop, because vImage uses SIMD/NEON optimizations. However, for V1, use a simple manual pixel loop for the CPU side to clearly demonstrate the GPU advantage. Document this in the benchmark results: "CPU: Single-threaded pixel iteration. GPU: Metal compute shader."

### 14.4 4096×4096 Safety

Before running 4096×4096:
```swift
let bytesNeeded = 4096 * 4096 * 4 * 3 // source + destination + intermediate
let mb = bytesNeeded / (1024 * 1024) // ~192 MB for 3 textures
```

iPhone 11 has 4 GB RAM. 192 MB is safe. However, add a check:
```swift
if resolution.0 * resolution.1 * 4 * 3 > 500_000_000 { // 500 MB safety limit
    // Skip this resolution
    return BenchmarkResult(resolution: resolution, skipped: true, reason: "Insufficient memory")
}
```

### 14.5 Benchmark Results Model

```swift
struct BenchmarkResult: Identifiable, Sendable {
    let id = UUID()
    let operationName: String
    let width: Int
    let height: Int
    let gpuTimeMs: Double
    let cpuTimeMs: Double?  // nil if CPU version not available
    let speedup: Double?    // nil if no CPU comparison
    let skipped: Bool
    let skipReason: String?
    
    var resolution: String { "\(width)×\(height)" }
    var pixelCount: Int { width * height }
}
```

### 14.6 Speedup Chart

Use SwiftUI `Charts` framework (available iOS 16+):

```swift
import Charts

struct SpeedupChartView: View {
    let results: [BenchmarkResult]
    
    var body: some View {
        Chart {
            ForEach(results.filter { !$0.skipped }) { result in
                BarMark(
                    x: .value("Resolution", result.resolution),
                    y: .value("Time (ms)", result.gpuTimeMs)
                )
                .foregroundStyle(.blue)
                .annotation(position: .top) {
                    Text(String(format: "%.1fms", result.gpuTimeMs))
                        .font(.caption2)
                }
                
                if let cpuTime = result.cpuTimeMs {
                    BarMark(
                        x: .value("Resolution", result.resolution),
                        y: .value("Time (ms)", cpuTime)
                    )
                    .foregroundStyle(.orange)
                }
            }
        }
        .chartLegend(position: .bottom)
        .frame(height: 250)
    }
}
```

---

## 15. Image Analysis — Histograms

### 15.1 Histogram Calculation — CPU-Based for V1

**Decision**: Use CPU-based histogram calculation in V1.

**Rationale**: GPU histogram requires atomic operations (Metal supports `atomic_fetch_add_explicit` on device buffers) and careful synchronization. While faster for very large images, a CPU histogram on a 4096×4096 image takes <50ms on A13, which is acceptable for non-real-time analysis. The GPU histogram is a V2 optimization.

```swift
struct HistogramData: Sendable {
    var red: [Int] = Array(repeating: 0, count: 256)
    var green: [Int] = Array(repeating: 0, count: 256)
    var blue: [Int] = Array(repeating: 0, count: 256)
    var luminance: [Int] = Array(repeating: 0, count: 256)
}

final class HistogramCalculator: Sendable {
    func calculate(from texture: MTLTexture) async -> HistogramData {
        // Read texture data to CPU
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        texture.getBytes(&pixelData,
                        bytesPerRow: bytesPerRow,
                        from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                       size: MTLSize(width: width, height: height, depth: 1)),
                        mipmapLevel: 0)
        
        var data = HistogramData()
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let b = Int(pixelData[offset])      // BGRA format
                let g = Int(pixelData[offset + 1])
                let r = Int(pixelData[offset + 2])
                
                data.red[r] += 1
                data.green[g] += 1
                data.blue[b] += 1
                
                // Luminance: BT.709
                let lum = Int(Float(r) * 0.2126 + Float(g) * 0.7152 + Float(b) * 0.0722)
                data.luminance[min(lum, 255)] += 1
            }
        }
        
        return data
    }
}
```

**Note on pixel order**: `.bgra8Unorm` stores bytes as B, G, R, A. The `getBytes` call reads raw bytes in this order.

### 15.2 Histogram Visualization

```swift
struct HistogramView: View {
    let data: [Int]
    let color: Color
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            GeometryReader { geo in
                let maxValue = max(data.max() ?? 1, 1)
                Path { path in
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) / 255.0 * geo.size.width
                        let h = CGFloat(value) / CGFloat(maxValue) * geo.size.height
                        path.addRect(CGRect(
                            x: x,
                            y: geo.size.height - h,
                            width: max(geo.size.width / 256.0, 1),
                            height: h
                        ))
                    }
                }
                .fill(color.opacity(0.7))
            }
            .frame(height: 100)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct RGBHistogramView: View {
    let data: HistogramData
    
    var body: some View {
        ZStack {
            HistogramView(data: data.red, color: .red, title: "")
            HistogramView(data: data.green, color: .green, title: "")
            HistogramView(data: data.blue, color: .blue, title: "")
        }
        .opacity(0.6) // Blend overlapping channels
    }
}
```

### 15.3 Image Info

```swift
struct ImageInfo: Sendable {
    let width: Int
    let height: Int
    let pixelCount: Int
    let format: String        // "JPEG", "PNG", "HEIF"
    let colorChannels: Int    // 4 (BGRA)
    let bitsPerComponent: Int // 8
    let bitsPerPixel: Int     // 32
    let colorSpace: String    // "sRGB"
    
    var megapixels: Double {
        Double(pixelCount) / 1_000_000.0
    }
}
```

---

## 16. Educational Information

### 16.1 Architecture

Each `ProcessingOperation` has an associated `EducationalInfo`:

```swift
struct EducationalInfo {
    let title: String
    let description: String
    let algorithmSteps: [String]
    let metalConcept: String
    let processingDiagram: String  // ASCII art or description
}

extension ProcessingOperation {
    var educationalInfo: EducationalInfo {
        switch self {
        case .gaussianBlur:
            return EducationalInfo(
                title: "Gaussian Blur",
                description: "Smooths the image by averaging each pixel with its neighbors, weighted by a Gaussian (bell curve) distribution.",
                algorithmSteps: [
                    "Compute 1D Gaussian weights based on sigma",
                    "Horizontal pass: blur each row using weighted average",
                    "Store intermediate result in a temporary texture",
                    "Vertical pass: blur each column of intermediate texture",
                    "Result: 2D Gaussian blur using only 2×(2r+1) samples instead of (2r+1)²"
                ],
                metalConcept: "Separable convolution using two compute shader passes, demonstrating multi-pass GPU processing with intermediate textures and command buffer synchronization.",
                processingDiagram: "Image → Horizontal Blur (GPU Pass 1) → Temp Texture → Vertical Blur (GPU Pass 2) → Blurred Image"
            )
        // ... similar for each operation
        }
    }
}
```

### 16.2 UI Integration

Educational info is accessible via an (i) info button next to each effect in the Effects tab and Pipeline view. Tapping it opens a `.sheet` with the educational content. Keep it concise — 3-5 sentences for description, bullet points for algorithm steps.

---

## 17. Presets

### 17.1 Preset Data Model

```swift
struct Preset: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var pipeline: ProcessingPipeline
    var dateCreated: Date
    var isBuiltIn: Bool
    
    static let builtInPresets: [Preset] = [
        Preset(id: UUID(), name: "Cinematic", pipeline: .cinematic, dateCreated: .distantPast, isBuiltIn: true),
        Preset(id: UUID(), name: "Warm", pipeline: .warm, dateCreated: .distantPast, isBuiltIn: true),
        Preset(id: UUID(), name: "High Contrast", pipeline: .highContrast, dateCreated: .distantPast, isBuiltIn: true),
        Preset(id: UUID(), name: "Black & White", pipeline: .blackAndWhite, dateCreated: .distantPast, isBuiltIn: true),
        Preset(id: UUID(), name: "Sharpened", pipeline: .sharpened, dateCreated: .distantPast, isBuiltIn: true),
    ]
}
```

#### Built-in Preset Configurations

```swift
extension ProcessingPipeline {
    static let cinematic = ProcessingPipeline(nodes: [
        PipelineNode(operation: .adjustments(AdjustmentParams(
            brightness: -0.05, contrast: 1.3, exposure: 0.2,
            saturation: 0.8, temperature: 0.15, tint: 0.0, gamma: 1.1
        )))
    ])
    
    static let warm = ProcessingPipeline(nodes: [
        PipelineNode(operation: .adjustments(AdjustmentParams(
            brightness: 0.05, contrast: 1.05, exposure: 0.1,
            saturation: 1.2, temperature: 0.3, tint: 0.05, gamma: 1.0
        )))
    ])
    
    static let highContrast = ProcessingPipeline(nodes: [
        PipelineNode(operation: .adjustments(AdjustmentParams(
            brightness: 0.0, contrast: 2.0, exposure: 0.0,
            saturation: 1.3, temperature: 0.0, tint: 0.0, gamma: 0.9
        )))
    ])
    
    static let blackAndWhite = ProcessingPipeline(nodes: [
        PipelineNode(operation: .adjustments(AdjustmentParams(
            brightness: 0.0, contrast: 1.2, exposure: 0.0,
            saturation: 1.0, temperature: 0.0, tint: 0.0, gamma: 1.0
        ))),
        PipelineNode(operation: .grayscale)
    ])
    
    static let sharpened = ProcessingPipeline(nodes: [
        PipelineNode(operation: .adjustments(AdjustmentParams(
            brightness: 0.0, contrast: 1.1, exposure: 0.0,
            saturation: 1.0, temperature: 0.0, tint: 0.0, gamma: 1.0
        ))),
        PipelineNode(operation: .sharpen(strength: 0.7))
    ])
}
```

### 17.2 Preset Storage

```swift
final class PresetManager {
    private let fileURL: URL
    
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("presets.json")
    }
    
    func loadPresets() -> [Preset] {
        guard let data = try? Data(contentsOf: fileURL),
              let presets = try? JSONDecoder().decode([Preset].self, from: data) else {
            return []
        }
        return presets
    }
    
    func savePresets(_ presets: [Preset]) {
        let userPresets = presets.filter { !$0.isBuiltIn }
        guard let data = try? JSONEncoder().encode(userPresets) else { return }
        try? data.write(to: fileURL)
    }
}
```

---

## 18. Undo / Redo

### 18.1 Strategy: Lightweight State Snapshots

Each undo state stores a `PipelineSnapshot`, NOT texture data:

```swift
struct PipelineSnapshot: Sendable {
    let pipeline: ProcessingPipeline
    let timestamp: Date
}
```

**Why state-based**: A pipeline snapshot is a few KB of Codable data. Storing texture data (a 4096×4096 BGRA texture = 64 MB) for every undo step would quickly exhaust memory. Since the pipeline is non-destructive, any historical state can be reconstructed by re-processing the original texture through the saved pipeline configuration.

### 18.2 Implementation

```swift
// In AppState:
private let maxUndoSteps = 50

func pushUndoState() {
    let snapshot = PipelineSnapshot(pipeline: pipeline, timestamp: Date())
    undoStack.append(snapshot)
    if undoStack.count > maxUndoSteps {
        undoStack.removeFirst()
    }
    redoStack.removeAll() // Clear redo on new action
}

func undo() {
    guard let previous = undoStack.popLast() else { return }
    let currentSnapshot = PipelineSnapshot(pipeline: pipeline, timestamp: Date())
    redoStack.append(currentSnapshot)
    pipeline = previous.pipeline
    reprocessImage()
}

func redo() {
    guard let next = redoStack.popLast() else { return }
    let currentSnapshot = PipelineSnapshot(pipeline: pipeline, timestamp: Date())
    undoStack.append(currentSnapshot)
    pipeline = next.pipeline
    reprocessImage()
}

var canUndo: Bool { !undoStack.isEmpty }
var canRedo: Bool { !redoStack.isEmpty }
```

### 18.3 When to Push Undo State

- Before adding a pipeline node
- Before removing a pipeline node
- Before reordering pipeline nodes
- Before changing filter parameters (debounced — push when slider interaction ENDS, not during drag)
- Before toggling a node's enable state
- Before applying a preset
- Before resetting pipeline

**NOT** pushed during:
- Slider drag (would create hundreds of states)
- Zoom/pan changes (these are view state, not processing state)

---

## 19. Reset System

### 19.1 Reset Operations

| Reset Action | What It Does |
|---|---|
| Reset individual adjustment | Set that adjustment parameter to default (e.g., brightness → 0.0) |
| Reset all adjustments | Set all 7 adjustment params to defaults |
| Reset individual effect | Remove that effect node from pipeline |
| Reset pipeline | Remove all nodes from pipeline |
| Reset image | Clear loaded image, return to empty state |
| Reset zoom | Set `zoomScale` = 1.0, `zoomOffset` = .zero |

All reset actions except zoom reset push an undo state before executing.

---

## 20. Export

### 20.1 Export Formats

```swift
enum ExportFormat: String, CaseIterable {
    case jpeg = "JPEG"
    case png = "PNG"
    case heif = "HEIF"
    
    var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .heif: return .heif
        }
    }
}
```

### 20.2 Texture to Exportable Image

```swift
final class ExportService {
    func exportImage(texture: MTLTexture, format: ExportFormat, 
                     quality: Float = 0.9) async throws -> Data {
        // Step 1: Read texture pixels to CPU
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        texture.getBytes(&pixelData,
                        bytesPerRow: bytesPerRow,
                        from: MTLRegion(origin: .init(), 
                                       size: MTLSize(width: width, height: height, depth: 1)),
                        mipmapLevel: 0)
        
        // Step 2: Create CGImage
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | 
                                                CGBitmapInfo.byteOrder32Little.rawValue)
        // BGRA → corresponds to byteOrder32Little + premultipliedFirst
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw ExportError.contextCreationFailed
        }
        
        guard let cgImage = context.makeImage() else {
            throw ExportError.imageCreationFailed
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        
        // Step 3: Encode
        switch format {
        case .jpeg:
            guard let data = uiImage.jpegData(compressionQuality: CGFloat(quality)) else {
                throw ExportError.encodingFailed
            }
            return data
            
        case .png:
            guard let data = uiImage.pngData() else {
                throw ExportError.encodingFailed
            }
            return data
            
        case .heif:
            // Use CIImage + CIContext for HEIF encoding
            let ciImage = CIImage(cgImage: cgImage)
            let ciContext = CIContext()
            guard let data = ciContext.heifRepresentation(
                of: ciImage,
                format: .BGRA8,
                colorSpace: colorSpace,
                options: [CIImageRepresentationOption.init(rawValue: kCGImageDestinationLossyCompressionQuality as String): quality]
            ) else {
                throw ExportError.encodingFailed
            }
            return data
        }
    }
    
    func saveToPhotos(data: Data, format: ExportFormat) async throws {
        // Use UIActivityViewController or PHPhotoLibrary
        // For V1, present UIActivityViewController (share sheet)
    }
}
```

**Color space**: Export in sRGB (device RGB). This matches the processing color space and is universally compatible.

**Large image handling**: For images > 4096×4096, the `pixelData` array can be large (>64 MB). Use `autoreleasepool` around the export to ensure timely deallocation:

```swift
try await autoreleasepool {
    // ... export code
}
```

**Memory for export**: Original resolution is preserved. The processed texture is at the same resolution as the original. No downscaling during export.

**HEIF availability**: HEIF encoding is available on all devices with iOS 11+. However, check at runtime:
```swift
let supportsHEIF = CIContext().isHEIFRepresentationSupported
```

---

## 21. Data Models — Complete Reference

### 21.1 All Model Types

```swift
// MARK: - Core Enums

enum AppTab: String, CaseIterable {
    case editor, effects, pipeline, performance, analysis
}

enum ComparisonMode: String, CaseIterable {
    case original = "Original"
    case processed = "Processed"
    case sideBySide = "Side by Side"
    case split = "Split"
}

enum ExportFormat: String, CaseIterable {
    case jpeg = "JPEG"
    case png = "PNG"
    case heif = "HEIF"
}

enum OperationCategory: String, CaseIterable {
    case adjustment = "Adjustments"
    case basic = "Basic"
    case blur = "Blur"
    case sharpen = "Sharpen"
    case edge = "Edge Detection"
    case pixelation = "Pixelation"
    case distortion = "Distortion"
    case convolution = "Convolution Lab"
}

// MARK: - Parameter Structs (matching Metal)

struct AdjustmentParams: Codable, Equatable, Sendable {
    var brightness: Float = 0.0
    var contrast: Float = 1.0
    var exposure: Float = 0.0
    var saturation: Float = 1.0
    var temperature: Float = 0.0
    var tint: Float = 0.0
    var gamma: Float = 1.0
    var _padding: Float = 0.0
    
    var isDefault: Bool {
        brightness == 0.0 && contrast == 1.0 && exposure == 0.0 &&
        saturation == 1.0 && temperature == 0.0 && tint == 0.0 && gamma == 1.0
    }
    
    static let `default` = AdjustmentParams()
}

struct RippleParams: Codable, Equatable, Sendable {
    var centerX: Float = 0.5
    var centerY: Float = 0.5
    var radius: Float = 0.5
    var strength: Float = 0.3
    var frequency: Float = 30.0
    var phase: Float = 0.0
}

struct SwirlParams: Codable, Equatable, Sendable {
    var centerX: Float = 0.5
    var centerY: Float = 0.5
    var radius: Float = 0.5
    var strength: Float = 0.5
}

// MARK: - Pipeline

struct ProcessingPipeline: Codable, Equatable, Sendable {
    var nodes: [PipelineNode] = []
    // ... methods as defined in §11.1
}

struct PipelineNode: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var operation: ProcessingOperation
    var isEnabled: Bool
}

enum ProcessingOperation: Codable, Equatable, Sendable {
    // ... as defined in §11.1
}

// MARK: - Convolution

struct ConvolutionKernel: Codable, Equatable, Sendable {
    var values: [Float]
    var divisor: Float
    var bias: Float
    var name: String
    // ... static presets as defined in §10.2
}

// MARK: - Performance

struct PerformanceMetrics: Sendable {
    // ... as defined in §13.1
}

struct BenchmarkResult: Identifiable, Sendable {
    // ... as defined in §14.5
}

// MARK: - Analysis

struct HistogramData: Sendable {
    // ... as defined in §15.1
}

struct ImageInfo: Sendable {
    // ... as defined in §15.3
}

// MARK: - Presets

struct Preset: Codable, Identifiable, Sendable {
    // ... as defined in §17.1
}

// MARK: - Undo

struct PipelineSnapshot: Sendable {
    let pipeline: ProcessingPipeline
    let timestamp: Date
}

// MARK: - Educational

struct EducationalInfo {
    // ... as defined in §16.1
}

// MARK: - Errors

enum MetalError: LocalizedError {
    case deviceNotAvailable
    case commandQueueCreationFailed
    case libraryNotFound
    case functionNotFound(String)
    case pipelineCreationFailed(String)
    case commandBufferCreationFailed
    case encoderCreationFailed
    case textureCreationFailed
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .deviceNotAvailable: return "Metal GPU is not available on this device."
        case .commandQueueCreationFailed: return "Failed to create Metal command queue."
        case .libraryNotFound: return "Metal shader library not found."
        case .functionNotFound(let name): return "Metal function '\(name)' not found."
        case .pipelineCreationFailed(let reason): return "Pipeline creation failed: \(reason)"
        case .commandBufferCreationFailed: return "Failed to create command buffer."
        case .encoderCreationFailed: return "Failed to create compute encoder."
        case .textureCreationFailed: return "Failed to create texture."
        case .processingFailed(let reason): return "Processing failed: \(reason)"
        }
    }
}

enum ImageError: LocalizedError {
    case importFailed
    case unsupportedFormat
    case textureFailed
    case imageTooLarge(Int, Int)
    case noImageLoaded
    
    var errorDescription: String? {
        switch self {
        case .importFailed: return "Failed to import image."
        case .unsupportedFormat: return "Image format not supported."
        case .textureFailed: return "Failed to create texture from image."
        case .imageTooLarge(let w, let h): return "Image too large (\(w)×\(h)). Maximum: 8192×8192."
        case .noImageLoaded: return "No image loaded."
        }
    }
}

enum ExportError: LocalizedError {
    case contextCreationFailed
    case imageCreationFailed
    case encodingFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .contextCreationFailed: return "Failed to create image context."
        case .imageCreationFailed: return "Failed to create image from texture."
        case .encodingFailed: return "Failed to encode image."
        case .saveFailed: return "Failed to save image."
        }
    }
}
```

---

## 22. File / Folder Structure

### 22.1 Complete Project Tree

```
MetalCraft/
│
├── App/
│   ├── MetalCraftApp.swift          # App entry point, creates AppState
│   └── AppState.swift               # Central observable state, coordinates all services
│
├── Models/
│   ├── AdjustmentParams.swift       # Adjustment parameter struct (matches Metal)
│   ├── ProcessingOperation.swift    # Operation enum with all cases
│   ├── ProcessingPipeline.swift     # Pipeline struct with node management
│   ├── PipelineNode.swift           # Individual pipeline node
│   ├── ConvolutionKernel.swift      # Kernel data + built-in presets
│   ├── DistortionParams.swift       # RippleParams, SwirlParams
│   ├── PerformanceMetrics.swift     # Metrics and BenchmarkResult
│   ├── HistogramData.swift          # Histogram + ImageInfo
│   ├── Preset.swift                 # Preset model + built-in presets
│   ├── ComparisonMode.swift         # Comparison mode enum
│   ├── ExportFormat.swift           # Export format enum
│   ├── EducationalInfo.swift        # Educational content per operation
│   └── Errors.swift                 # MetalError, ImageError, ExportError
│
├── Views/
│   ├── ContentView.swift            # TabView with 5 tabs
│   ├── Editor/
│   │   ├── EditorView.swift         # Editor tab root
│   │   ├── ImageCanvasView.swift    # Zoomable/pannable image display
│   │   ├── AdjustmentPanelView.swift # Adjustment sliders container
│   │   ├── AdjustmentSliderRow.swift # Individual slider row component
│   │   ├── ComparisonView.swift     # Comparison mode switcher
│   │   └── SplitComparisonView.swift # Split divider comparison
│   ├── Effects/
│   │   ├── EffectsView.swift        # Effects tab root
│   │   ├── EffectCategoryList.swift # Categorized effect browser
│   │   ├── EffectParameterView.swift # Parameter controls per effect
│   │   └── ConvolutionLabView.swift # Custom kernel editor
│   ├── Pipeline/
│   │   ├── PipelineView.swift       # Pipeline tab root
│   │   ├── PipelineNodeRow.swift    # Individual node row
│   │   └── AddOperationSheet.swift  # Sheet to add new operation
│   ├── Performance/
│   │   ├── PerformanceView.swift    # Performance tab root
│   │   ├── GPUDashboardView.swift   # Metrics cards grid
│   │   ├── MetricCard.swift         # Individual metric card
│   │   ├── BenchmarkControlView.swift # Benchmark configuration UI
│   │   └── BenchmarkResultsView.swift # Results table + chart
│   ├── Analysis/
│   │   ├── AnalysisView.swift       # Analysis tab root
│   │   ├── HistogramView.swift      # Single-channel histogram
│   │   ├── RGBHistogramView.swift   # Overlaid RGB histogram
│   │   └── ImageInfoView.swift      # Image metadata display
│   └── Shared/
│       ├── EducationalSheet.swift   # Educational info sheet
│       ├── EmptyStateView.swift     # Empty state placeholder
│       └── ErrorAlertModifier.swift # Error presentation modifier
│
├── Metal/
│   ├── MetalContext.swift           # MTLDevice, MTLCommandQueue, MTLLibrary
│   ├── MetalProcessor.swift         # Core processing engine
│   ├── TexturePool.swift            # Texture allocation/reuse pool
│   └── TextureLoader.swift          # UIImage/CGImage ↔ MTLTexture conversion
│
├── Services/
│   ├── ImageManager.swift           # Image import via PhotosPicker
│   ├── ExportService.swift          # Image export (JPEG, PNG, HEIF)
│   ├── PresetManager.swift          # Preset save/load (JSON file)
│   ├── BenchmarkEngine.swift        # CPU vs GPU benchmark runner
│   └── HistogramCalculator.swift    # CPU-based histogram computation
│
├── Shaders/
│   ├── ShaderTypes.h                # Shared C header (Swift bridging + Metal)
│   └── Shaders.metal               # All compute kernel implementations
│
├── Resources/
│   └── Assets.xcassets/             # App icon, accent color (already exists)
│
├── MetalCraft.entitlements          # (already exists)
├── Info.plist                       # (already exists, will be modified)
└── MetalCraft-Bridging-Header.h    # Bridging header to include ShaderTypes.h
```

### 22.2 File Responsibilities

#### App/MetalCraftApp.swift
- **Responsibility**: App entry point. Creates `MetalContext` and `AppState`. Handles app lifecycle.
- **Key**: Remove all SwiftData boilerplate. No `ModelContainer`.
- **Creates**: `AppState` as `@State`, injects via `.environment()`

#### App/AppState.swift
- **Responsibility**: Central source of truth. Holds all observable properties. Coordinates between views and services.
- **Key Properties**: `originalImage`, `processedTexture`, `displayImage`, `pipeline`, `performanceMetrics`, `histogramData`, `undoStack`/`redoStack`, `presets`
- **Key Methods**: `importImage(_:)`, `reprocessImage()`, `addPipelineNode(_:)`, `removePipelineNode(at:)`, `movePipelineNode(from:to:)`, `undo()`, `redo()`, `applyPreset(_:)`, `savePreset(name:)`, `resetPipeline()`, `exportImage(format:)`

#### Models/*.swift
- **Responsibility**: Pure data types. No business logic. All `Codable`, `Sendable`, `Equatable`.
- **Key**: `ProcessingOperation` is the `enum` that drives the entire pipeline. Its cases exactly match the shader functions.

#### Views/Editor/ImageCanvasView.swift
- **Responsibility**: Displays the current image (original or processed based on comparison mode). Handles pinch-to-zoom and pan gestures.
- **Key**: Uses `MagnificationGesture` and `DragGesture` simultaneously. Clamps zoom to [0.5, 10.0]. Displays the `displayImage` from `AppState`.

#### Metal/MetalProcessor.swift
- **Responsibility**: The GPU processing engine. Owns `TexturePool`. Creates and caches `MTLComputePipelineState`. Encodes and dispatches compute shaders. Returns processed texture and timing metrics.
- **Key Methods**: `process(pipeline:sourceTexture:)`, `encodeAdjustments(...)`, `encodeGaussianBlur(...)`, `encodeConvolution(...)`, `encodeSobel(...)`, `encodePixelate(...)`, `encodeRipple(...)`, `encodeSwirl(...)`, `encodeGrayscale(...)`, `encodeInvert(...)`

#### Metal/TextureLoader.swift
- **Responsibility**: Converts between `UIImage`/`CGImage` and `MTLTexture`. Handles color space normalization.
- **Key Methods**: `textureFromUIImage(_:device:)` → `MTLTexture`, `uiImageFromTexture(_:)` → `UIImage`

#### Services/ImageManager.swift
- **Responsibility**: Image import using `PhotosUI.PhotosPicker`. Loads selected image, creates `UIImage`, delegates texture creation to `TextureLoader`.
- **API**: Uses `PhotosPicker` (SwiftUI, iOS 16+) with `PhotosPickerItem`. Loads via `item.loadTransferable(type: Data.self)` then `UIImage(data:)`.

#### Services/BenchmarkEngine.swift
- **Responsibility**: Runs CPU vs GPU benchmarks across resolutions. Creates test textures. Implements CPU reference algorithms. Measures timing. Handles warm-up and averaging.
- **Key**: CPU implementations are simple pixel-loop versions of grayscale, invert, blur (box blur 3×3), and adjustments.

#### Shaders/Shaders.metal
- **Responsibility**: ALL Metal compute shader implementations. One file for V1 simplicity.
- **Functions**: `adjustments_kernel`, `grayscale_kernel`, `invert_kernel`, `gaussian_blur_h_kernel`, `gaussian_blur_v_kernel`, `convolution_kernel`, `sobel_kernel`, `pixelate_kernel`, `ripple_kernel`, `swirl_kernel`

#### Shaders/ShaderTypes.h
- **Responsibility**: Shared C struct definitions used by both Swift (via bridging header) and Metal (via `#include`).
- **Structs**: `AdjustmentParams`, `ConvolutionParams`, `GaussianBlurParams`, `EffectParams`, `DistortionParams`

#### MetalCraft-Bridging-Header.h
- **Content**: `#import "ShaderTypes.h"`
- **Purpose**: Makes Metal parameter structs available in Swift without duplicating definitions

---

## 23. Image Management — Import Details

### 23.1 Image Import API

Use SwiftUI `PhotosPicker` (from `PhotosUI`):

```swift
import PhotosUI

struct EditorView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedItem: PhotosPickerItem? = nil
    
    var body: some View {
        // ...
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Label("Import", systemImage: "photo.badge.plus")
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                await appState.importImage(from: newItem)
            }
        }
    }
}
```

### 23.2 Image Loading Flow

```swift
// In AppState:
func importImage(from item: PhotosPickerItem?) async {
    guard let item else { return }
    isProcessing = true
    
    do {
        // Load image data
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw ImageError.importFailed
        }
        
        guard let uiImage = UIImage(data: data) else {
            throw ImageError.unsupportedFormat
        }
        
        // Check size limits
        let width = Int(uiImage.size.width * uiImage.scale)
        let height = Int(uiImage.size.height * uiImage.scale)
        if width > 8192 || height > 8192 {
            throw ImageError.imageTooLarge(width, height)
        }
        
        // Create Metal texture
        guard let texture = TextureLoader.textureFromUIImage(uiImage, device: metalProcessor.context.device) else {
            throw ImageError.textureFailed
        }
        
        // Set state
        originalImage = uiImage
        originalTexture = texture
        processedTexture = texture // Initially, processed = original
        displayImage = uiImage
        pipeline = ProcessingPipeline() // Reset pipeline for new image
        undoStack.removeAll()
        redoStack.removeAll()
        zoomScale = 1.0
        zoomOffset = .zero
        
        // Calculate initial analysis
        histogramData = await histogramCalculator.calculate(from: texture)
        imageInfo = ImageInfo(
            width: texture.width, height: texture.height,
            pixelCount: texture.width * texture.height,
            format: detectFormat(data: data),
            colorChannels: 4, bitsPerComponent: 8, bitsPerPixel: 32,
            colorSpace: "sRGB"
        )
        
    } catch {
        errorMessage = error.localizedDescription
        showError = true
    }
    
    isProcessing = false
}
```

### 23.3 Format Detection

```swift
func detectFormat(data: Data) -> String {
    guard data.count >= 4 else { return "Unknown" }
    let header = [UInt8](data.prefix(4))
    
    if header[0] == 0xFF && header[1] == 0xD8 { return "JPEG" }
    if header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47 { return "PNG" }
    if data.count >= 12 {
        let ftypHeader = [UInt8](data[4..<8])
        if String(bytes: ftypHeader, encoding: .ascii) == "ftyp" { return "HEIF" }
    }
    return "Unknown"
}
```

### 23.4 UIImage → MTLTexture Conversion

```swift
enum TextureLoader {
    static func textureFromUIImage(_ image: UIImage, device: MTLDevice) -> MTLTexture? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared // Required for CPU write + GPU read on iOS
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        
        // Render CGImage into BGRA pixel buffer
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue |
                                                CGBitmapInfo.byteOrder32Little.rawValue)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        texture.replace(
            region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                             size: MTLSize(width: width, height: height, depth: 1)),
            mipmapLevel: 0,
            withBytes: pixelData,
            bytesPerRow: bytesPerRow
        )
        
        return texture
    }
    
    static func uiImageFromTexture(_ texture: MTLTexture) -> UIImage? {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        texture.getBytes(&pixelData,
                        bytesPerRow: bytesPerRow,
                        from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                       size: MTLSize(width: width, height: height, depth: 1)),
                        mipmapLevel: 0)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue |
                                                CGBitmapInfo.byteOrder32Little.rawValue)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        guard let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
```

**Why `storageMode: .shared`**: On iOS, `.shared` storage means CPU and GPU can both access the texture memory. This is required because we write pixel data from CPU (`texture.replace`) and read it on GPU (shader). On iOS, `.private` storage would prevent CPU writes. `.managed` does not exist on iOS.

---

## 24. Concurrency Model

### 24.1 Threading Strategy

```
Main Thread (@MainActor):
├── All SwiftUI views
├── AppState (state mutations, UI updates)
├── MetalProcessor (pipeline state cache, texture pool)
└── Initiates GPU processing

Background Thread (Swift Concurrency):
├── commandBuffer.waitUntilCompleted()
├── Histogram calculation
├── CPU benchmark execution
├── Image data encoding (export)
└── Preset file I/O

GPU (Asynchronous):
├── Compute shader execution
└── Texture operations
```

### 24.2 Processing Flow

```swift
// In AppState:
func reprocessImage() {
    guard let sourceTexture = originalTexture else { return }
    guard !pipeline.enabledNodes.isEmpty else {
        // No operations — display original
        displayImage = originalImageAsUIImage
        processedTexture = sourceTexture
        performanceMetrics = PerformanceMetrics()
        return
    }
    
    isProcessing = true
    
    Task.detached { [pipeline, metalProcessor] in
        do {
            let (resultTexture, metrics) = try await metalProcessor.process(
                pipeline: pipeline,
                sourceTexture: sourceTexture
            )
            
            let resultImage = TextureLoader.uiImageFromTexture(resultTexture)
            
            await MainActor.run {
                self.processedTexture = resultTexture
                self.displayImage = resultImage
                self.performanceMetrics = metrics
                self.isProcessing = false
            }
            
            // Update histogram in background
            if let texture = resultTexture {
                let histogram = await self.histogramCalculator.calculate(from: texture)
                await MainActor.run {
                    self.histogramData = histogram
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isProcessing = false
            }
        }
    }
}
```

**Why `Task.detached`**: We want `waitUntilCompleted()` to run on a background thread, NOT the main actor's executor. A regular `Task {}` inside an `@MainActor` class would still inherit the main actor context. `Task.detached` ensures background execution.

**But MetalProcessor is @MainActor**: Yes — its methods are called from the detached task, which means they'll hop to the main actor for cache lookups and encoding setup, then the `waitUntilCompleted` is the only blocking call that runs off main. The actual pattern is:

```swift
// In MetalProcessor:
func process(pipeline: ProcessingPipeline, sourceTexture: MTLTexture) async throws -> (MTLTexture, PerformanceMetrics) {
    // This runs on @MainActor (encoding, pipeline state creation)
    let commandBuffer = ... 
    // ... encode all operations ...
    
    let startTime = CACurrentMediaTime()
    commandBuffer.commit()
    
    // Move to background for waiting
    return try await withCheckedThrowingContinuation { continuation in
        commandBuffer.addCompletedHandler { [weak self] cb in
            let endTime = CACurrentMediaTime()
            if let error = cb.error {
                continuation.resume(throwing: MetalError.processingFailed(error.localizedDescription))
            } else {
                var metrics = PerformanceMetrics()
                metrics.gpuTimeMs = (endTime - startTime) * 1000.0
                // ... fill other metrics ...
                continuation.resume(returning: (resultTexture, metrics))
            }
        }
    }
}
```

**Better approach using `addCompletedHandler`**: This avoids blocking any thread. The continuation resumes when the GPU finishes. This is the recommended V1 approach.

### 24.3 Debouncing Slider Updates

When the user drags a slider, we should not reprocess on every frame. Debounce with a small delay:

```swift
struct AdjustmentSliderRow: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let defaultValue: Float
    let onChanged: () -> Void
    
    @State private var debounceTask: Task<Void, Never>? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption.monospacedDigit())
                if value != defaultValue {
                    Button("Reset") { 
                        value = defaultValue
                        onChanged()
                    }
                    .font(.caption2)
                }
            }
            Slider(value: $value, in: range)
                .onChange(of: value) { _, _ in
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(for: .milliseconds(50))
                        if !Task.isCancelled {
                            onChanged()
                        }
                    }
                }
        }
    }
}
```

50ms debounce means max 20 reprocesses per second during slider drag — smooth enough for real-time feel without overwhelming the GPU.

---

## 25. Memory Management

### 25.1 Texture Memory Budget

| Texture | Size at 4096×4096 | Count | Total |
|---|---|---|---|
| Original | 64 MB | 1 | 64 MB |
| Processed (final) | 64 MB | 1 | 64 MB |
| Intermediate (pool) | 64 MB | 2 | 128 MB |
| Gaussian blur temp | 64 MB | 1 | 64 MB |
| **Total** | | | **320 MB** |

iPhone 11 has 4 GB RAM, with ~1.5-2 GB available to apps. 320 MB is within budget but significant.

### 25.2 Memory Safety Rules

1. **Maximum practical resolution**: 8192×8192 (256 MB per texture). Beyond this, reject with error.
2. **Texture pool limit**: Maximum 4 textures in pool. If pool is full, oldest is released.
3. **Drain pool on memory warning**:
   ```swift
   NotificationCenter.default.addObserver(
       forName: UIApplication.didReceiveMemoryWarningNotification,
       object: nil, queue: .main
   ) { [weak self] _ in
       self?.texturePool.drain()
   }
   ```
4. **Autoreleasepool for bulk operations**: Wrap export and histogram calculation in `autoreleasepool`.
5. **Never copy original texture unnecessarily**: The original texture is created once and never modified. Pipeline always reads from it (or from intermediate textures).
6. **Release intermediate textures**: After pipeline processing, all intermediate textures return to pool or are released.

### 25.3 Large Image Handling

```swift
func validateImageSize(_ image: UIImage) throws {
    let width = Int(image.size.width * image.scale)
    let height = Int(image.size.height * image.scale)
    
    if width > 8192 || height > 8192 {
        throw ImageError.imageTooLarge(width, height)
    }
    
    // Also check total memory
    let bytesNeeded = width * height * 4 * 3 // Rough: source + destination + intermediate
    if bytesNeeded > 500_000_000 { // 500 MB safety
        throw ImageError.imageTooLarge(width, height)
    }
}
```

---

## 26. Error Handling

### 26.1 Error Presentation

All errors flow through `AppState.errorMessage` and `AppState.showError`:

```swift
// In ContentView:
.alert("Error", isPresented: $appState.showError) {
    Button("OK") { appState.showError = false }
} message: {
    Text(appState.errorMessage ?? "An unknown error occurred.")
}
```

### 26.2 Error Scenarios and Handling

| Error | Detection | User Message | Recovery |
|---|---|---|---|
| No Metal device | `MTLCreateSystemDefaultDevice()` returns nil | "Metal GPU is not available on this device." | Show error on launch, app cannot function |
| Image import failed | `loadTransferable` throws or returns nil | "Failed to import image. Please try another image." | Dismiss, try again |
| Unsupported format | `UIImage(data:)` returns nil | "Image format not supported." | Dismiss, try different image |
| Texture creation failed | `device.makeTexture()` returns nil | "Failed to create GPU texture." | Dismiss (likely memory) |
| Shader not found | `library.makeFunction()` returns nil | "Internal error: shader not found." | Fatal — indicates build issue |
| Pipeline creation failed | `makeComputePipelineState` throws | "Failed to compile GPU shader." | Dismiss — should not happen with valid shaders |
| Command buffer failure | `cb.error` is non-nil | "GPU processing failed." | Dismiss, retry |
| Memory pressure | `didReceiveMemoryWarning` | "Running low on memory. Try a smaller image." | Drain texture pool, warn user |
| Export failure | Encoding returns nil | "Failed to export image." | Dismiss, retry |
| Invalid convolution kernel | Divisor == 0 | "Divisor cannot be zero." | Inline validation, prevent apply |
| Oversized image | Width or height > 8192 | "Image too large (WxH). Maximum: 8192×8192." | Dismiss, try smaller image |

---

## 27. iPhone 11 Compatibility

### 27.1 Device Specifications

| Feature | iPhone 11 |
|---|---|
| Chip | A13 Bionic |
| Metal Family | Apple GPU Family 6 |
| RAM | 4 GB |
| Max texture size | 16384×16384 |
| `dispatchThreads` support | Yes (Apple 4+) |
| Non-uniform threadgroups | Yes (Apple 4+) |
| Read-write textures (tier 2) | Yes |
| iOS 26 support | Yes (A13 and later) |

### 27.2 Deployment Target

- **Minimum iOS**: 26.5 (already configured in project)
- **This means**: All modern APIs available (`@Observable`, `PhotosPicker`, Swift Charts, etc.)

### 27.3 No Hardware-Specific Concerns for V1

All Metal features used in V1 are available on Apple GPU Family 4+. iPhone 11 (Family 6) supports everything with significant margin. No fallback paths are needed.

### 27.4 Runtime Device Check

Add at app launch as a safety net:

```swift
guard MTLCreateSystemDefaultDevice() != nil else {
    // Show full-screen error: "This app requires a device with Metal GPU support."
    return
}
```

---

## 28. Performance Optimization

### 28.1 Performance Goals

| Goal | Target | Method |
|---|---|---|
| UI responsiveness | No frame drops during slider drag | Debounce processing (50ms) |
| Adjustment preview latency | <100ms on iPhone 11 at 4K | Single combined kernel, cached pipeline |
| Gaussian blur at σ=5 on 2048² | <50ms | Separable two-pass, optimized threadgroups |
| Memory usage | <400 MB peak | Texture pool, drain on warning |
| App launch to ready | <2 seconds | Lazy pipeline state creation |
| Export time for 4K JPEG | <1 second | Background encoding |

### 28.2 Optimization Rules

1. **Process only when parameters change**: Track `lastProcessedPipeline` hash. Skip if unchanged.
2. **Debounce slider updates**: 50ms delay before processing.
3. **Cache pipeline states**: Never re-compile shaders.
4. **Reuse textures**: Pool intermediate textures.
5. **Single command buffer**: All pipeline stages in one command buffer.
6. **Minimize CPU↔GPU copies**: Only read back to CPU for display (`uiImageFromTexture`) and analysis.
7. **Lazy histogram**: Calculate histogram after processing completes, not during.
8. **Skip disabled nodes**: `pipeline.enabledNodes` filters before iteration.

---

## 29. Testing Strategy

### 29.1 Functional Tests (MetalCraftTests)

| Test | What to Verify |
|---|---|
| `testImageImport` | Load a test image, verify texture dimensions match |
| `testAdjustmentDefaults` | Verify `AdjustmentParams.default` produces identity (no visible change) |
| `testGrayscale` | Process a known-color pixel, verify luminance output |
| `testInvert` | Process (255,0,0), verify (0,255,255) |
| `testConvolutionIdentity` | Apply identity kernel [0,0,0,0,1,0,0,0,0], verify output equals input |
| `testConvolutionKernelValidation` | Verify divisor=0 is rejected |
| `testPipelineAdd` | Add nodes, verify pipeline.nodes.count |
| `testPipelineRemove` | Remove node, verify count decreases |
| `testPipelineReorder` | Move node, verify order changes |
| `testPipelineToggle` | Disable node, verify enabledNodes excludes it |
| `testUndoRedo` | Perform action, undo, verify state restored |
| `testPresetSaveLoad` | Save preset, reload, verify equality |
| `testExportJPEG` | Export processed texture as JPEG, verify non-empty data |
| `testExportPNG` | Export as PNG, verify PNG header bytes |
| `testGaussianWeights` | Verify weights sum to ~1.0 for various sigma values |
| `testTexturePoolAcquireRelease` | Acquire, release, re-acquire — verify same texture reused |

### 29.2 Metal Tests (MetalCraftTests)

| Test | What to Verify |
|---|---|
| `testMetalContextCreation` | MetalContext initializes successfully |
| `testPipelineStateCreation` | All shader functions can create pipeline states |
| `testTextureCreation` | Create textures at various sizes (512² to 4096²) |
| `testBoundaryHandling` | Process a 1×1 texture without crash |
| `testLargeTexture` | Process 4096×4096 without crash or memory error |
| `testAllShadersExecute` | Run each shader on a test texture, verify no command buffer error |

### 29.3 Simulator vs Device Testing

| Aspect | Simulator | Device (iPhone 11) |
|---|---|---|
| UI layout | ✅ Full testing | ✅ Final verification |
| Metal shaders | ⚠️ Simulated GPU (may differ) | ✅ Real GPU execution |
| Performance metrics | ❌ Not meaningful | ✅ Real measurements |
| Benchmark | ❌ Not meaningful | ✅ Required |
| Memory pressure | ⚠️ Different limits | ✅ Real constraints |
| Photo import | ⚠️ Limited library | ✅ Full test |
| Export | ✅ Functional test | ✅ Full test |

**Rule**: All functional tests must pass on simulator. All performance and GPU-specific tests must pass on physical device.

---

## 30. Implementation Phases

### PHASE 1: Project Foundation
**Goal**: Clean project, Metal context, basic app structure.

**Files to CREATE**:
- `MetalCraft/App/AppState.swift`
- `MetalCraft/Metal/MetalContext.swift`
- `MetalCraft/Models/Errors.swift`
- `MetalCraft/Shaders/ShaderTypes.h`
- `MetalCraft/Shaders/Shaders.metal` (empty, with header include)
- `MetalCraft/MetalCraft-Bridging-Header.h`
- `MetalCraft/Views/Shared/EmptyStateView.swift`

**Files to MODIFY**:
- `MetalCraft/App/MetalCraftApp.swift` — Remove SwiftData, create MetalContext + AppState, set up TabView
- `MetalCraft/ContentView.swift` — Replace with TabView structure (5 tabs, each showing placeholder)
- `MetalCraft/Info.plist` — Add `NSPhotoLibraryUsageDescription`
- `project.pbxproj` — Configure bridging header setting (`SWIFT_OBJC_BRIDGING_HEADER = MetalCraft/MetalCraft-Bridging-Header.h`)

**Files to DELETE**:
- `MetalCraft/Item.swift` (SwiftData model)

**Implementation Details**:
- `MetalContext.init()` creates device, queue, library
- `AppState` is `@Observable`, holds reference to `MetalContext`
- `MetalCraftApp` creates `MetalContext`, shows error if nil, otherwise creates `AppState`
- Each tab is a placeholder `Text("Editor")`, etc.
- The bridging header must be configured in build settings

**Testing**: App launches, shows 5 tabs, no crashes. Metal context initialized (print confirmation in debug console).

**Common Failures**:
- Bridging header path wrong → "bridging header not found" build error
- `ShaderTypes.h` not found by Metal file → ensure header search paths include project dir
- SwiftData references remaining → linker errors

---

### PHASE 2: Metal Processor + Texture Infrastructure
**Goal**: Create the core processing engine, texture pool, and texture loader.

**Files to CREATE**:
- `MetalCraft/Metal/MetalProcessor.swift`
- `MetalCraft/Metal/TexturePool.swift`
- `MetalCraft/Metal/TextureLoader.swift`

**Implementation Details**:
- `MetalProcessor` initializes with `MetalContext`, creates samplers
- `TexturePool` implements acquire/release with key-based caching
- `TextureLoader` implements `textureFromUIImage` and `uiImageFromTexture`
- `MetalProcessor.getOrCreatePipeline()` implemented with cache dictionary
- `MetalProcessor.dispatchThreads()` helper implemented

**Testing**: Unit test — create a 100×100 texture, verify dimensions. Create `MetalProcessor`, verify no crash.

**Common Failures**:
- `storageMode: .private` on iOS → CPU can't write → use `.shared`
- Pixel format mismatch between CGContext and MTLTexture → use BGRA consistently

---

### PHASE 3: Image Import + Display
**Goal**: User can import an image from Photos and see it on screen.

**Files to CREATE**:
- `MetalCraft/Services/ImageManager.swift`
- `MetalCraft/Views/Editor/EditorView.swift`
- `MetalCraft/Views/Editor/ImageCanvasView.swift`
- `MetalCraft/Models/ComparisonMode.swift`

**Files to MODIFY**:
- `MetalCraft/App/AppState.swift` — Add `importImage()`, image state properties
- `MetalCraft/Views/ContentView.swift` — Wire EditorView to first tab
- `MetalCraft/Info.plist` — Verify `NSPhotoLibraryUsageDescription` key

**Implementation Details**:
- `EditorView` contains `PhotosPicker`, `ImageCanvasView`
- `ImageCanvasView` displays `appState.displayImage` with zoom/pan gestures
- `MagnificationGesture` for pinch zoom, `DragGesture` for pan
- Double-tap to reset zoom
- Image fits to screen width by default

**Testing**: Import a JPEG, PNG, and HEIF image. Verify display. Pinch to zoom, pan, double-tap to reset.

**Common Failures**:
- Missing `NSPhotoLibraryUsageDescription` → crash on import attempt
- Image orientation not handled → UIImage respects orientation but CGImage may not → draw through CGContext normalizes orientation

---

### PHASE 4: Basic Adjustments
**Goal**: All 7 adjustments work with real-time GPU processing.

**Files to CREATE**:
- `MetalCraft/Models/AdjustmentParams.swift`
- `MetalCraft/Views/Editor/AdjustmentPanelView.swift`
- `MetalCraft/Views/Editor/AdjustmentSliderRow.swift`

**Files to MODIFY**:
- `MetalCraft/Shaders/ShaderTypes.h` — Add `AdjustmentParams` struct
- `MetalCraft/Shaders/Shaders.metal` — Add `adjustments_kernel`
- `MetalCraft/Metal/MetalProcessor.swift` — Add `encodeAdjustments()`
- `MetalCraft/App/AppState.swift` — Add adjustment state, `reprocessImage()`
- `MetalCraft/Views/Editor/EditorView.swift` — Add `AdjustmentPanelView`

**Implementation Details**:
- Swift `AdjustmentParams` struct must match Metal `AdjustmentParams` exactly (32 bytes)
- 7 sliders with ranges as specified in §9.1
- Each slider change triggers debounced `reprocessImage()`
- `reprocessImage()` creates command buffer, encodes adjustments, submits, reads back result

**Testing**: Import image, adjust each slider independently. Verify visual change. Reset individual slider, verify return to original. Reset all adjustments.

**Common Failures**:
- Struct alignment mismatch → garbled colors → add `MemoryLayout` assertion
- `waitUntilCompleted` on main thread → UI freeze → use `addCompletedHandler` pattern
- Slider drag too sensitive → add 50ms debounce

---

### PHASE 5: Basic Effects + Pipeline Model
**Goal**: Grayscale and Invert effects work. Pipeline data model established.

**Files to CREATE**:
- `MetalCraft/Models/ProcessingOperation.swift`
- `MetalCraft/Models/ProcessingPipeline.swift`
- `MetalCraft/Models/PipelineNode.swift`
- `MetalCraft/Views/Effects/EffectsView.swift`
- `MetalCraft/Views/Effects/EffectCategoryList.swift`

**Files to MODIFY**:
- `MetalCraft/Shaders/Shaders.metal` — Add `grayscale_kernel`, `invert_kernel`
- `MetalCraft/Metal/MetalProcessor.swift` — Add `encodeGrayscale()`, `encodeInvert()`, modify `process()` to iterate pipeline
- `MetalCraft/App/AppState.swift` — Add pipeline property, `addPipelineNode()`, `removePipelineNode()`
- `MetalCraft/Views/ContentView.swift` — Wire EffectsView to second tab

**Implementation Details**:
- `ProcessingOperation` enum with all cases (only grayscale and invert functional now)
- `MetalProcessor.process()` loops through `pipeline.enabledNodes`, encoding each operation
- Ping-pong texture pattern established
- Effects tab shows categorized list, tapping adds to pipeline

**Testing**: Add Grayscale → image turns B&W. Add Invert → colors inverted. Add both → grayscale then inverted (white = black).

---

### PHASE 6: Gaussian Blur
**Goal**: Separable Gaussian blur with adjustable sigma.

**Files to CREATE**:
- `MetalCraft/Views/Effects/EffectParameterView.swift`

**Files to MODIFY**:
- `MetalCraft/Shaders/ShaderTypes.h` — Add `GaussianBlurParams`
- `MetalCraft/Shaders/Shaders.metal` — Add `gaussian_blur_h_kernel`, `gaussian_blur_v_kernel`
- `MetalCraft/Metal/MetalProcessor.swift` — Add `encodeGaussianBlur()`, `computeGaussianWeights()`
- `MetalCraft/App/AppState.swift` — Wire blur to pipeline

**Implementation Details**:
- Two compute encoders in one command buffer
- Intermediate texture from pool
- Kernel weights computed on CPU, passed via `setBytes`
- Sigma slider [0.1, 20.0]

**Testing**: Apply blur at various sigma values. Verify visual smoothing. Test at sigma=0.1 (near identity) and sigma=20 (very blurry). Verify no artifacts at edges.

**Common Failures**:
- Weights array not properly passed → garbage blur → use `withUnsafeMutableBytes`
- Intermediate texture not returned to pool → memory leak → add `addCompletedHandler`
- Boundary check missing in shader → edge artifacts

---

### PHASE 7: Convolution Engine + Sharpen + Sobel + Pixelation + Distortion
**Goal**: All remaining effects implemented.

**Files to CREATE**:
- `MetalCraft/Models/ConvolutionKernel.swift`
- `MetalCraft/Models/DistortionParams.swift`
- `MetalCraft/Views/Effects/ConvolutionLabView.swift`

**Files to MODIFY**:
- `MetalCraft/Shaders/ShaderTypes.h` — Add `ConvolutionParams`, `EffectParams`, `DistortionParams`
- `MetalCraft/Shaders/Shaders.metal` — Add `convolution_kernel`, `sobel_kernel`, `pixelate_kernel`, `ripple_kernel`, `swirl_kernel`
- `MetalCraft/Metal/MetalProcessor.swift` — Add encoding methods for all new effects
- `MetalCraft/Views/Effects/EffectsView.swift` — Add all categories
- `MetalCraft/Views/Effects/EffectParameterView.swift` — Add parameter UI for each effect

**Implementation Details**:
- Convolution Lab: 3×3 grid of TextFields, divisor field, bias field, strength slider
- Built-in kernel buttons populate the grid
- Custom kernel validated before apply
- Sharpen uses `convolution_kernel` with sharpen matrix
- Sobel uses dedicated `sobel_kernel` for efficiency (two kernels in one pass)
- Pixelation uses block-size parameter
- Ripple and Swirl use center/radius/strength parameters

**Testing**: Test each effect independently. Test convolution lab with custom kernels:
- Identity kernel → no change
- Edge kernel `[-1,-1,-1,-1,8,-1,-1,-1,-1]` → edges highlighted
- Zero kernel → black (with zero bias) or gray (with 0.5 bias)

---

### PHASE 8: Pipeline View + Reordering
**Goal**: Visual pipeline editor with add/remove/reorder/enable-disable.

**Files to CREATE**:
- `MetalCraft/Views/Pipeline/PipelineView.swift`
- `MetalCraft/Views/Pipeline/PipelineNodeRow.swift`
- `MetalCraft/Views/Pipeline/AddOperationSheet.swift`

**Files to MODIFY**:
- `MetalCraft/App/AppState.swift` — Add `movePipelineNode()`, `togglePipelineNode()`
- `MetalCraft/Views/ContentView.swift` — Wire PipelineView to third tab

**Implementation Details**:
- `List` with `ForEach` using `.onMove` and `.onDelete` modifiers
- `EditButton()` in toolbar enables reorder mode
- Each row shows: enable toggle, operation name, parameter summary, info button
- Add operation sheet categorizes available operations
- Removing a node triggers reprocessing

**Testing**: Add 3 operations. Reorder them — verify processing order changes (visual difference). Disable middle operation — verify it's skipped. Delete operation — verify it's removed.

---

### PHASE 9: Before/After Comparison
**Goal**: All 4 comparison modes working.

**Files to MODIFY**:
- `MetalCraft/Views/Editor/EditorView.swift` — Add comparison mode picker
- `MetalCraft/Views/Editor/ImageCanvasView.swift` — Display based on mode

**Files to CREATE**:
- `MetalCraft/Views/Editor/ComparisonView.swift`
- `MetalCraft/Views/Editor/SplitComparisonView.swift`

**Implementation Details**:
- `Picker` in toolbar for comparison mode
- Original mode shows `originalImage`
- Processed mode shows `displayImage`
- Side-by-side uses `HStack`
- Split uses `GeometryReader` with draggable divider

**Testing**: Process an image. Switch through all 4 modes. In split mode, drag divider left and right.

---

### PHASE 10: Performance Dashboard
**Goal**: Real GPU metrics displayed.

**Files to CREATE**:
- `MetalCraft/Models/PerformanceMetrics.swift`
- `MetalCraft/Views/Performance/PerformanceView.swift`
- `MetalCraft/Views/Performance/GPUDashboardView.swift`
- `MetalCraft/Views/Performance/MetricCard.swift`

**Files to MODIFY**:
- `MetalCraft/Metal/MetalProcessor.swift` — Return `PerformanceMetrics` from processing
- `MetalCraft/App/AppState.swift` — Store and update `performanceMetrics`
- `MetalCraft/Views/ContentView.swift` — Wire PerformanceView to fourth tab

**Implementation Details**:
- Timing via `CACurrentMediaTime()` and `addCompletedHandler`
- Pass count tracked during encoding
- Metrics cards in 2-column grid
- Empty state when no image processed

**Testing**: Import image, apply effects. Verify metrics update. Verify values are realistic (not zero, not absurdly large).

---

### PHASE 11: CPU vs GPU Benchmark
**Goal**: Benchmarking system with real measurements.

**Files to CREATE**:
- `MetalCraft/Services/BenchmarkEngine.swift`
- `MetalCraft/Views/Performance/BenchmarkControlView.swift`
- `MetalCraft/Views/Performance/BenchmarkResultsView.swift`

**Files to MODIFY**:
- `MetalCraft/App/AppState.swift` — Add benchmark state, `runBenchmark()`
- `MetalCraft/Views/Performance/PerformanceView.swift` — Add benchmark section

**Implementation Details**:
- `BenchmarkEngine` creates test textures, runs warm-up, measures CPU and GPU
- CPU implementations: simple pixel loops for grayscale, invert, box blur
- Results stored as `[BenchmarkResult]`
- Swift Charts bar chart showing CPU vs GPU times per resolution
- Progress indicator during benchmark
- 4096×4096 safety check

**Testing**: Run benchmark on device. Verify GPU times < CPU times (they should be). Verify times are reasonable. Verify 4096² doesn't crash.

---

### PHASE 12: Histogram + Analysis
**Goal**: RGB and luminance histograms, image info.

**Files to CREATE**:
- `MetalCraft/Services/HistogramCalculator.swift`
- `MetalCraft/Models/HistogramData.swift`
- `MetalCraft/Views/Analysis/AnalysisView.swift`
- `MetalCraft/Views/Analysis/HistogramView.swift`
- `MetalCraft/Views/Analysis/RGBHistogramView.swift`
- `MetalCraft/Views/Analysis/ImageInfoView.swift`

**Files to MODIFY**:
- `MetalCraft/App/AppState.swift` — Add histogram calculation triggers
- `MetalCraft/Views/ContentView.swift` — Wire AnalysisView to fifth tab

**Implementation Details**:
- CPU-based histogram calculation (see §15.1)
- Histogram calculated after each pipeline process
- RGB histogram: overlaid red, green, blue channels at 0.6 opacity
- Luminance histogram: single gray channel
- Image info: resolution, megapixels, format, channels, bit depth

**Testing**: Import various images. Verify histograms look reasonable. A bright image should have histogram skewed right. A dark image skewed left. Grayscale image should have identical R, G, B histograms.

---

### PHASE 13: Educational Info
**Goal**: Educational content for each effect.

**Files to CREATE**:
- `MetalCraft/Models/EducationalInfo.swift`
- `MetalCraft/Views/Shared/EducationalSheet.swift`

**Files to MODIFY**:
- `MetalCraft/Views/Effects/EffectCategoryList.swift` — Add info buttons
- `MetalCraft/Views/Pipeline/PipelineNodeRow.swift` — Add info buttons

**Implementation Details**:
- `EducationalInfo` computed property on `ProcessingOperation`
- Info button (ⓘ) next to each effect/node opens `.sheet`
- Content: title, description, algorithm steps, Metal concept, processing diagram

**Testing**: Tap info button for each effect. Verify content displays correctly. Content should be factual and concise.

---

### PHASE 14: Presets
**Goal**: Built-in and custom presets.

**Files to CREATE**:
- `MetalCraft/Models/Preset.swift`
- `MetalCraft/Services/PresetManager.swift`

**Files to MODIFY**:
- `MetalCraft/App/AppState.swift` — Add preset management methods
- `MetalCraft/Views/Editor/EditorView.swift` — Add preset picker/menu

**Implementation Details**:
- 5 built-in presets with predefined pipeline configurations
- Custom presets saved as JSON in Documents directory
- Save preset: capture current pipeline configuration
- Load preset: replace current pipeline, trigger reprocess
- Delete preset: remove from storage and list
- Presets menu accessible from Editor toolbar

**Testing**: Apply each built-in preset. Save a custom preset. Close and reopen app. Verify custom preset persists. Delete custom preset.

---

### PHASE 15: Undo/Redo
**Goal**: Lightweight state-based undo/redo.

**Files to MODIFY**:
- `MetalCraft/App/AppState.swift` — Add undo/redo stack, methods, trigger pushes
- `MetalCraft/Views/Editor/EditorView.swift` — Add undo/redo buttons in toolbar

**Implementation Details**:
- Push state before every pipeline mutation
- Max 50 undo states
- Redo stack cleared on new action
- Undo/redo buttons show disabled state when stack empty

**Testing**: Make 5 changes. Undo all 5. Redo 3. Make new change — verify redo stack cleared.

---

### PHASE 16: Export
**Goal**: Export processed image in JPEG, PNG, HEIF.

**Files to CREATE**:
- `MetalCraft/Services/ExportService.swift`
- `MetalCraft/Models/ExportFormat.swift`

**Files to MODIFY**:
- `MetalCraft/App/AppState.swift` — Add `exportImage()` method
- `MetalCraft/Views/Editor/EditorView.swift` — Add export button + format picker

**Implementation Details**:
- Export button in Editor toolbar
- Format picker (JPEG, PNG, HEIF)
- Use `UIActivityViewController` for share sheet
- Export at original resolution from processed texture
- Show progress during export
- Error alert if export fails

**Testing**: Export in each format. Open exported file — verify quality and resolution match. Test with 4096×4096 image.

---

### PHASE 17: Polish + Final Testing
**Goal**: UI polish, error handling, edge cases, final testing.

**Tasks**:
1. Add proper SF Symbols to all tab items
2. Add app icon to Assets.xcassets
3. Ensure Dark Mode works throughout
4. Test all error paths (import failure, large image, etc.)
5. Verify memory usage with Instruments
6. Test on iPhone 11 physical device
7. Run full test suite
8. Fix any remaining compiler warnings
9. Add `CFBundleDisplayName = "GPU Image Lab"` to Info.plist
10. Verify accessibility labels
11. Remove any `print()` debug statements
12. Verify all comparison modes
13. Verify pipeline reordering produces correct visual results
14. Verify export preserves resolution
15. Verify presets persist across app launches
16. Test with very small images (100×100) and very large (4096×4096)
17. Verify benchmark on physical device

---

## 31. Final Acceptance Criteria

The application is complete when ALL of the following are verified:

- [ ] App launches and shows 5-tab interface
- [ ] Image import works for JPEG, PNG, HEIF
- [ ] Imported images display correctly with proper orientation
- [ ] Pinch-to-zoom and pan work smoothly
- [ ] Double-tap resets zoom
- [ ] All 7 adjustments produce correct visual changes
- [ ] Each adjustment slider shows numeric value
- [ ] Individual adjustment reset works
- [ ] Reset all adjustments works
- [ ] Grayscale effect works correctly
- [ ] Invert effect works correctly
- [ ] Gaussian blur works with adjustable sigma
- [ ] Gaussian blur uses two-pass separable implementation
- [ ] Sharpen works with strength parameter
- [ ] Sobel edge detection works with strength parameter
- [ ] Pixelation works with block size parameter
- [ ] Ripple distortion works with center/radius/strength/frequency
- [ ] Swirl distortion works with center/radius/strength
- [ ] Convolution Lab displays 3×3 input grid
- [ ] Built-in convolution kernels (Blur, Sharpen, Edge, Emboss) work
- [ ] Custom 3×3 kernel input works
- [ ] Custom kernel validation rejects divisor=0
- [ ] Pipeline view shows all active operations
- [ ] Pipeline nodes can be added
- [ ] Pipeline nodes can be removed
- [ ] Pipeline nodes can be reordered (visual change confirms order matters)
- [ ] Pipeline nodes can be enabled/disabled
- [ ] Original comparison mode shows unprocessed image
- [ ] Processed comparison mode shows processed image
- [ ] Side-by-side comparison works
- [ ] Split comparison has draggable divider
- [ ] GPU Performance Dashboard shows real metrics
- [ ] Image resolution and pixel count display correctly
- [ ] GPU processing time is measured (not fabricated)
- [ ] Pass count is accurate
- [ ] CPU vs GPU benchmark runs on physical device
- [ ] Benchmark shows results for 512², 1024², 2048², 4096²
- [ ] Benchmark shows speedup calculation
- [ ] Benchmark chart displays correctly
- [ ] RGB histogram displays correctly
- [ ] Luminance histogram displays correctly
- [ ] Image info (resolution, format, channels, bit depth) displays
- [ ] Educational info is available for each effect
- [ ] 5 built-in presets apply correctly
- [ ] Custom presets can be saved
- [ ] Custom presets can be loaded
- [ ] Custom presets can be deleted
- [ ] Custom presets persist across app launches
- [ ] Undo works for pipeline changes
- [ ] Redo works after undo
- [ ] Redo stack clears on new action
- [ ] Export JPEG works
- [ ] Export PNG works
- [ ] Export HEIF works (where supported)
- [ ] Export preserves original resolution
- [ ] Large images (4096×4096) don't crash the app
- [ ] Very small images (100×100) work without issues
- [ ] Error alerts display for failure cases
- [ ] Memory warning is handled (texture pool drained)
- [ ] No V2 features have been added
- [ ] No fake/placeholder core features
- [ ] No hardcoded GPU statistics
- [ ] UI is responsive during processing (no main thread blocking)
- [ ] App works on iPhone 11
- [ ] Dark Mode is supported
- [ ] No major compiler warnings
- [ ] All Metal shaders compile without errors
- [ ] App display name is "GPU Image Lab"

---

## 32. Gemini Implementation Instructions

### MANDATORY RULES

1. **Do not rewrite working code unnecessarily.** If a phase is complete and tested, do not refactor it in a later phase unless there is a specific, documented reason.

2. **Do not create duplicate managers.** There is ONE `MetalProcessor`, ONE `AppState`, ONE `TexturePool`. Do not create "MetalRenderer", "GPUEngine", "FilterManager" etc.

3. **Do not use fake GPU processing.** Every effect MUST use actual Metal compute shaders. Do not use `CIFilter`, `CoreImage`, or `vImage` as the primary processing pipeline. These are Apple's high-level wrappers. The entire point of this app is to demonstrate direct Metal usage.

4. **Do not hardcode performance values.** Every metric must be measured at runtime using `CACurrentMediaTime()` or equivalent. Never write `gpuTimeMs = 0.5`.

5. **Do not claim unsupported GPU statistics.** If an API does not expose a metric, do not display it. See §13.2 for what IS and IS NOT measurable.

6. **Do not use placeholder implementations.** Every feature listed in V1 must be fully functional. "TODO: implement later" is not acceptable for V1 features.

7. **Do not silently remove existing functionality.** When modifying a file, preserve all existing working code unless the modification explicitly replaces it.

8. **Keep the project compiling after each phase.** Every phase must end with a buildable, runnable app. Do not leave broken code between phases.

9. **Test on a physical iPhone.** Metal performance and behavior differ significantly between simulator and device. The simulator uses a translated Metal implementation.

10. **Fix compiler errors before moving to the next phase.** Never leave errors to be "fixed later."

11. **Verify Metal shader/resource compatibility.** After writing a shader, verify the parameter struct sizes match between Swift and Metal using `MemoryLayout` assertions.

12. **Avoid deprecated APIs.** The deployment target is iOS 26.5. Use modern APIs: `@Observable` (not `ObservableObject`), `PhotosPicker` (not `UIImagePickerController`), `.onChange(of:) { oldValue, newValue in }` (not the deprecated single-parameter closure).

13. **Avoid unnecessary third-party dependencies.** Use ZERO third-party packages. Everything is built with Apple's frameworks: SwiftUI, Metal, MetalKit (only if needed), PhotosUI, Charts, CoreImage (only for HEIF export).

14. **Prefer Apple's native frameworks.** Do not import UIKit views unless there is no SwiftUI equivalent. Do not use Objective-C patterns.

15. **Keep architecture modular.** Each file has a single responsibility. Views are thin. Business logic is in AppState and services.

16. **Explain any unavoidable tradeoffs.** If a design decision has a downside, add a brief code comment explaining why it was chosen.

17. **Do not add V2 features.** Do not implement video processing, camera input, additional filters, layer compositing, custom shader editor, or anything not explicitly listed in the V1 scope.

18. **Do not sacrifice stability for visual effects.** The app must not crash. Graceful error handling is more important than visual polish.

### FILE ORGANIZATION RULE

The Xcode project uses `PBXFileSystemSynchronizedRootGroup`. This means any file placed inside the `MetalCraft/` directory is automatically included in the build. You do NOT need to modify `project.pbxproj` to add new Swift or Metal files. You DO need to modify it to:
- Set the bridging header path (`SWIFT_OBJC_BRIDGING_HEADER`)
- The rest is handled by file system synchronization

### BRIDGING HEADER SETUP

The bridging header MUST be configured in the Xcode project's build settings. Add to both Debug and Release configurations of the MetalCraft target:
```
SWIFT_OBJC_BRIDGING_HEADER = MetalCraft/MetalCraft-Bridging-Header.h
```

The bridging header file:
```objc
// MetalCraft-Bridging-Header.h
#import "ShaderTypes.h"
```

The `ShaderTypes.h` file is placed in `MetalCraft/Shaders/ShaderTypes.h`. The Metal file includes it via:
```metal
#include "ShaderTypes.h"
```

For the Metal compiler to find it, ensure the header search path includes the Shaders directory. In build settings:
```
MTL_HEADER_SEARCH_PATHS = $(SRCROOT)/MetalCraft/Shaders
```

For the Swift bridging header to find `ShaderTypes.h`, the bridging header must use the correct relative path:
```objc
// MetalCraft-Bridging-Header.h
#import "Shaders/ShaderTypes.h"
```

Or add to `HEADER_SEARCH_PATHS`:
```
HEADER_SEARCH_PATHS = $(SRCROOT)/MetalCraft/Shaders
```

---

## 33. Common Mistakes to Avoid

| Mistake | Why It's Wrong | Correct Approach |
|---|---|---|
| Using `CIFilter` for processing | Wraps GPU details, defeats purpose of the app | Direct Metal compute shaders |
| Using `ObservableObject` + `@Published` | Causes unnecessary view re-renders | Use `@Observable` macro |
| Calling `waitUntilCompleted()` on main thread | Freezes UI | Use `addCompletedHandler` with continuation |
| Creating new `MTLDevice` per operation | Expensive, wasteful | Create once in `MetalContext`, share everywhere |
| Creating new pipeline states per frame | Expensive recompilation | Cache in dictionary by function name |
| Storing texture data in undo stack | Massive memory usage | Store lightweight `PipelineSnapshot` |
| Reprocessing when parameters haven't changed | Wasted GPU cycles | Check equality before processing |
| Using `.private` storage mode on iOS textures that need CPU access | CPU can't read/write | Use `.shared` |
| Forgetting boundary checks in shaders | Out-of-bounds reads → garbage pixels | Always check `gid.x >= width` |
| Using `Float3` in shader param struct | 16-byte aligned, not 12 | Pad to 16 bytes or use separate floats |
| Not normalizing Gaussian weights | Blur produces dark/bright output | Divide by sum of weights |
| Hardcoding threadgroup size | May exceed device limits | Use `pipeline.threadExecutionWidth` and `maxTotalThreadsPerThreadgroup` |

---

## 34. Future Features — V2 ONLY

The following are explicitly NOT part of V1 and must not be implemented:

- Real-time camera input with live Metal processing
- Video frame processing
- Batch image processing
- Layer compositing
- Custom shader code editor (user writes Metal)
- Cloud storage/sync
- GPU histogram computation (using atomic counters)
- Additional edge-detection algorithms (Prewitt, Laplacian, Canny)
- Additional distortion modes (barrel, pincushion, fisheye)
- HDR / wide-gamut color space support
- Metal Performance Shaders (MPS) integration for optimized kernels
- GPU counter sample buffers for precise GPU-only timing
- iPad-specific multi-pane layout
- Animated GIF/APNG export
- Machine learning-based effects (CoreML + Metal)
- Texture compression formats
- Multi-resolution processing (pyramid)
- Localization beyond English
