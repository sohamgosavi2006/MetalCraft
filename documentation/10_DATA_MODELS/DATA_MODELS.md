# Data Models Reference

## Core Models

### ProcessingOperation
**File**: `MetalCraft/Models/ProcessingOperation.swift`

Enum with associated values representing each GPU operation:
```swift
enum ProcessingOperation: Codable, Equatable, Sendable {
    case adjustments(AdjustmentParams)
    case grayscale
    case invert
    case gaussianBlur(sigma: Float)
    case sharpen(strength: Float)
    case sobelEdge(strength: Float, blend: Float)
    case pixelate(blockSize: Float)
    case ripple(RippleConfig)
    case swirl(SwirlConfig)
    case convolution(ConvolutionKernel, strength: Float)
}
```

### AdjustmentParams
**File**: `MetalCraft/Models/AdjustmentParams.swift`

```swift
struct AdjustmentParams: Codable, Equatable, Sendable {
    var brightness: Float = 0.0     // -1.0 to 1.0
    var contrast: Float = 1.0       // 0.0 to 3.0
    var exposure: Float = 0.0       // -3.0 to 3.0
    var saturation: Float = 1.0     // 0.0 to 3.0
    var temperature: Float = 0.0    // -1.0 to 1.0
    var tint: Float = 0.0           // -1.0 to 1.0
    var gamma: Float = 1.0          // 0.1 to 3.0
}
```

### Project
**File**: `MetalCraft/Models/Project.swift`

```swift
struct Project: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var name: String
    var images: [ProjectImage]
    var videos: [ProjectVideo]
    var createdAt: Date
    var modifiedAt: Date
}

struct ProjectImage: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var fileName: String
    var pipeline: ProcessingPipeline
    var adjustments: AdjustmentParams
    var imageInfo: ImageInfo?
    var addedAt: Date
}

struct ProjectVideo: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var fileName: String
    var pipeline: ProcessingPipeline
    var adjustments: AdjustmentParams
    var videoInfo: VideoInfo?
    var addedAt: Date
}
```

### VideoInfo
```swift
struct VideoInfo: Codable, Sendable, Equatable {
    var duration: Double
    var width: Int
    var height: Int
    var frameRate: Float
    var hasAudio: Bool
    var codec: String
    var fileSizeBytes: Int64
}
```

## New Models (to be created)

### EditPlan (Phase 1)
```swift
struct EditPlan: Codable, Sendable {
    let schemaVersion: String
    let planId: String
    let createdAt: Date
    let mediaType: MediaType
    let goal: String
    let reasoning: String
    let researchContext: String?
    let adjustments: EditPlanAdjustments
    let operations: [EditPlanOperation]
    let output: EditPlanOutput
}

struct EditPlanOperation: Codable, Sendable {
    let type: String
    let enabled: Bool
    let parameters: [String: AnyCodableValue]
}
```

### AgentState (Phase 1)
```swift
enum AgentState: String, Sendable {
    case idle, analyzing, researching, planning, validating,
         waitingForApproval, executing, observing, evaluating,
         revising, completed, failed, cancelled, timeout
}
```

### TelemetryEvent (Phase 3)
```swift
struct TelemetryEvent: Codable, Sendable {
    let eventType: String
    let timestamp: Date
    let sessionId: String
    let requestId: String?
    let operation: String?
    let processingTimeMs: Double?
    let gpuTimeMs: Double?
    let passCount: Int?
    let resolution: String?
    let mediaType: String?
    let errorMessage: String?
}
```
