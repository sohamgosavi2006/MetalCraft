# Video Processing Architecture

## Overview

MetalCraft uses the SAME Metal GPU pipeline for both images and videos. Video frames are extracted as CVPixelBuffer, converted to MTLTexture via CVMetalTextureCache (zero-copy), processed through MetalProcessor, and rendered via MetalVideoView (MTKView).

## Components

### VideoPlayerController

**File**: `MetalCraft/Services/VideoPlayerController.swift`

**Responsibilities**:
- AVPlayer + AVPlayerItem management
- CADisplayLink-synchronized frame extraction
- AVPlayerItemVideoOutput for pixel buffer access
- Preferred transform extraction for orientation correction
- Play/pause/seek/scrub controls

**Key Properties**:
- `currentRawTexture: MTLTexture?` — unprocessed frame
- `currentProcessedTexture: MTLTexture?` — after GPU pipeline
- `isPlaying: Bool`
- `currentTime: CMTime`
- `duration: CMTime`
- `preferredTransform: CGAffineTransform` — orientation from video track

### VideoTextureProvider

**File**: `MetalCraft/Services/VideoTextureProvider.swift`

**Purpose**: Converts CVPixelBuffer → MTLTexture with zero CPU copy.

**Flow**:
```
CVPixelBuffer (from AVPlayerItemVideoOutput)
    │
    ▼
CVMetalTextureCache.createTextureFromImage()
    │  Zero-copy: GPU reads directly from pixel buffer memory
    ▼
CVMetalTexture
    │
    ▼
CVMetalTextureGetTexture() → MTLTexture
```

### MetalVideoView

**File**: `MetalCraft/Views/Editor/MetalVideoView.swift`

**Purpose**: MTKView-based UIViewRepresentable for direct GPU rendering.

**Orientation Correction**:
```swift
// 1. Flip Y axis (Metal top-left → CoreImage bottom-left)
let yFlipped = ciImage.transformed(by: CGAffineTransform(scaleX: 1.0, y: -1.0)
    .translatedBy(x: 0, y: -ciImage.extent.height))

// 2. Apply video's preferred transform (rotation/flip)
let oriented = yFlipped.transformed(by: preferredTransform)

// 3. Normalize origin to (0, 0)
let normalized = oriented.transformed(by: CGAffineTransform(
    translationX: -oriented.extent.origin.x,
    y: -oriented.extent.origin.y))
```

### VideoExportService

**File**: `MetalCraft/Services/VideoExportService.swift`

**Purpose**: Export GPU-processed video using AVAssetWriter.

**Flow**:
1. Create AVAssetReader for source video
2. Create AVAssetWriter for output
3. For each frame:
   - Read CVPixelBuffer from asset reader
   - Convert to MTLTexture via VideoTextureProvider
   - Process through MetalProcessor (same pipeline as preview)
   - Convert result back to CVPixelBuffer
   - Append to asset writer
4. Copy audio track without modification
5. Finalize output

### VideoManager

**File**: `MetalCraft/Services/VideoManager.swift`

**Purpose**: Extract video metadata (duration, resolution, FPS, codec, file size, audio presence).

## Real-Time Processing Budget

At 30 FPS, each frame has ~33ms budget:
- Frame extraction: ~2ms
- CVPixelBuffer → MTLTexture: ~0.5ms (zero-copy)
- GPU processing (pipeline): varies by operations
- MTKView rendering: ~2ms

Simple effects (grayscale, invert): ~5ms total → 60+ FPS possible
Complex effects (blur + convolution + edge): ~20-30ms → 30 FPS maintained
Very complex (multiple blurs, distortions): may drop frames, reduce to proxy resolution
