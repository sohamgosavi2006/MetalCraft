# Metal Craft — Metal GPU Processing Specification

### Tagline
**Professional Image Processing Powered by Metal**

---

## 1. Metal Architecture Components

### 1.1 `MetalContext`
- Instantiates and owns the global system default `MTLDevice`, default `MTLCommandQueue`, and default `MTLLibrary`.
- Initialized once during app launch and injected into `MetalProcessor`.

### 1.2 `MetalProcessor`
- Manages compute pipeline state compilation and thread-safe caching (`computePipelines: [String: MTLComputePipelineState]`).
- Manages the `TexturePool` for intermediate ping-pong textures.
- Provides specialized encoders for:
  - Combined adjustments (`adjustments_kernel`)
  - Separable Gaussian Blur horizontal & vertical passes (`gaussian_blur_h_kernel`, `gaussian_blur_v_kernel`)
  - Generic 3×3 convolution (`convolution_kernel`)
  - Sobel Edge Detection gradient calculation (`sobel_kernel`)
  - Pixelation / Mosaic (`pixelate_kernel`)
  - Ripple Distortion (`ripple_kernel`)
  - Swirl Distortion (`swirl_kernel`)
  - Grayscale & Invert (`grayscale_kernel`, `invert_kernel`)

---

## 2. Compute Shader Execution Model

### 2.1 Why Compute Shaders (vs Fragment Shaders)
- No render pass or framebuffer setup (`MTLRenderPassDescriptor` is avoided).
- Direct mapping of 2D grid dimensions to image width and height.
- Direct read/write access to 2D textures (`texture2d<float, access::read>`, `texture2d<float, access::write>`).
- Significantly lower command encoding overhead for sequential filters.

### 2.2 Threadgroup Configuration
- Threadgroup width: `min(pipeline.threadExecutionWidth, imageWidth)` (typically 32 on Apple Silicon).
- Threadgroup height: `min(pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth, imageHeight)` (typically 32 on Apple Silicon).
- Dispatches: `encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)` with safety boundary checks in every shader:
  ```metal
  if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;
  ```

---

## 3. Shader Parameter Structures & Memory Alignment

All parameter structs are defined in `ShaderTypes.h` and shared across C/Metal and Swift via bridging header:

| Struct | Size (bytes) | Alignment | Purpose |
|---|---|---|---|
| `AdjustmentParams` | 32 | 4 | Brightness, Contrast, Exposure, Saturation, Temperature, Tint, Gamma |
| `ConvolutionParams` | 64 | 4 | 3×3 matrix, divisor, bias, strength, dimensions |
| `GaussianBlurParams` | 528 | 4 | 127 float weights, radius, dimensions, axis flag |
| `EffectParams` | 32 | 4 | Strength, param1..3, dimensions |
| `DistortionParams` | 32 | 4 | Center (X,Y), radius, strength, frequency, phase, dimensions |

---

## 4. Multi-Pass Pipeline & Intermediate Texture Flow

When a pipeline contains multiple operations:
1. `sourceTexture` is passed to Stage 1.
2. An intermediate texture `texA` is acquired from `TexturePool`.
3. Stage 1 executes: `sourceTexture` -> `texA`.
4. Stage 2 acquires `texB`.
5. Stage 2 executes: `texA` -> `texB`. `texA` is released back to pool.
6. For Gaussian Blur, 2 internal passes are executed:
   - Horizontal: `currentSource` -> `tempBlurTexture` (Pass 1)
   - Vertical: `tempBlurTexture` -> `destinationTexture` (Pass 2)
7. All encoders are recorded into a single `MTLCommandBuffer` to minimize GPU synchronization overhead.
