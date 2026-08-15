# Metal GPU Engine

## Overview

MetalCraft's GPU engine is built on Apple Metal and provides real-time image and video processing through compute shaders.

## Core Components

### MetalContext

**File**: `MetalCraft/Metal/MetalContext.swift`

**Purpose**: Holds the singleton Metal infrastructure created once at app launch.

| Property | Type | Purpose |
|----------|------|---------|
| `device` | `MTLDevice` | GPU hardware abstraction |
| `commandQueue` | `MTLCommandQueue` | Serial queue for command buffers |
| `library` | `MTLLibrary` | Compiled Metal shader library |

**Concurrency**: `Sendable` — safe to share across threads.

**Initialization**: Failable `init?()` — returns nil if Metal is unavailable. Searches multiple bundle paths for `default.metallib` to support both app and test targets.

### MetalProcessor

**File**: `MetalCraft/Metal/MetalProcessor.swift`

**Purpose**: Dispatches compute shader operations on MTLTextures.

**Processing Flow**:
1. Receives `ProcessingOperation` + input `MTLTexture`
2. Creates `MTLComputePipelineState` from shader function name
3. Creates `MTLCommandBuffer` from `MetalContext.commandQueue`
4. Encodes compute command with textures + parameter buffer
5. Dispatches threadgroups (16×16 threads)
6. Commits and waits for completion
7. Returns output `MTLTexture`

**Thread Safety**: Processes on background thread, result published on main thread.

### TexturePool

**File**: `MetalCraft/Metal/TexturePool.swift`

**Purpose**: Reusable cache of MTLTextures to avoid repeated GPU memory allocation.

**Key Behavior**:
- Caches by `(width, height, pixelFormat)` tuple
- Returns cached texture if available, creates new one otherwise
- Reduces memory churn during rapid pipeline processing

### TextureLoader

**File**: `MetalCraft/Metal/TextureLoader.swift`

**Purpose**: Converts between UIImage and MTLTexture.

**Key Methods**:
- `textureFromUIImage(_:device:)` — UIImage → MTLTexture
- `uiImageFromTexture(_:)` — MTLTexture → UIImage (for SwiftUI display)

## Compute Shader Architecture

All shaders are in `MetalCraft/Shaders/Shaders.metal` with shared C structs in `ShaderTypes.h`.

### Thread Dispatch Pattern

Every kernel follows the same pattern:
```metal
kernel void operation_kernel(
    texture2d<float, access::read>  inTexture  [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant Params &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    // Bounds check
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;
    
    // Read, process, write
    float4 color = inTexture.read(gid);
    // ... processing ...
    outTexture.write(result, gid);
}
```

### Shader Parameter Types (ShaderTypes.h)

| Struct | Used By | Fields |
|--------|---------|--------|
| `AdjustmentParams` | adjustments_kernel | brightness, contrast, exposure, saturation, temperature, tint, gamma |
| `GaussianBlurParams` | gaussian_blur_h/v_kernel | radius, weights[64], texWidth, texHeight |
| `ConvolutionParams` | convolution_kernel | weights[9], divisor, bias, strength, texWidth, texHeight |
| `EffectParams` | sobel_kernel, pixelate_kernel | strength, param1, texWidth, texHeight |
| `DistortionParams` | ripple_kernel, swirl_kernel | centerX, centerY, radius, strength, frequency, phase, texWidth, texHeight |

## Extension Points

To add a new GPU operation:
1. Define a new struct in `ShaderTypes.h` (if needed)
2. Add a new kernel function in `Shaders.metal`
3. Add a new case to `ProcessingOperation` enum
4. Add the dispatch logic in `MetalProcessor`
5. Add a new case to `EditPlan` operation type mapping (for agent support)
