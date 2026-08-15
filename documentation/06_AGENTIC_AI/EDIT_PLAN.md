# EditPlan Schema — AI-to-Editor Contract

## Purpose

The EditPlan is the formal, versioned JSON contract between the Gemini agent and MetalCraft. Every AI editing instruction must be expressed as an EditPlan. MetalCraft validates the EditPlan and deterministically translates it into ProcessingPipeline operations.

## Schema Definition (v1.0)

```json
{
  "schemaVersion": "1.0",
  "planId": "uuid-string",
  "createdAt": "ISO-8601 timestamp",
  "mediaType": "image | video",
  "goal": "Human-readable description of the creative intent",
  "reasoning": "Agent's explanation of why these operations were chosen",
  "researchContext": "Optional summary from Parallel research, or null",

  "adjustments": {
    "brightness": 0.0,
    "contrast": 1.0,
    "exposure": 0.0,
    "saturation": 1.0,
    "temperature": 0.0,
    "tint": 0.0,
    "gamma": 1.0
  },

  "operations": [
    {
      "type": "gaussianBlur",
      "enabled": true,
      "parameters": {
        "sigma": 2.5
      }
    },
    {
      "type": "sobelEdge",
      "enabled": true,
      "parameters": {
        "strength": 1.0,
        "blend": 0.5
      }
    }
  ],

  "output": {
    "format": "jpeg | png | heif | mp4",
    "quality": 0.95
  }
}
```

## Supported Operation Types

These map 1:1 to existing ProcessingOperation enum cases:

| EditPlan type | ProcessingOperation | Required Parameters |
|--------------|-------------------|-------------------|
| `"adjustments"` | `.adjustments(params)` | brightness, contrast, exposure, saturation, temperature, tint, gamma |
| `"grayscale"` | `.grayscale` | None |
| `"invert"` | `.invert` | None |
| `"gaussianBlur"` | `.gaussianBlur(sigma:)` | sigma: Float |
| `"sharpen"` | `.sharpen(strength:)` | strength: Float |
| `"sobelEdge"` | `.sobelEdge(strength:blend:)` | strength: Float, blend: Float |
| `"pixelate"` | `.pixelate(blockSize:)` | blockSize: Float |
| `"ripple"` | `.ripple(config)` | frequency: Float, strength: Float, radius: Float, centerX: Float, centerY: Float, phase: Float |
| `"swirl"` | `.swirl(config)` | radius: Float, strength: Float, centerX: Float, centerY: Float |
| `"convolution"` | `.convolution(kernel, strength:)` | kernelName: String, strength: Float |

## Validation Rules

1. `schemaVersion` must be "1.0" (or supported version)
2. `mediaType` must be "image" or "video"
3. Each operation `type` must exist in the supported types table
4. Each operation's `parameters` must contain all required keys for that type
5. Parameter values must be within safe ranges (e.g., sigma 0.1–50.0, strength 0.0–1.0)
6. `operations` array must not exceed 20 entries (prevent agent loops)
7. `output.format` must be a supported ExportFormat
8. `output.quality` must be 0.0–1.0

## Translation to ProcessingPipeline

```swift
// EditPlanExecutor.swift (NEW file)
func execute(_ editPlan: EditPlan) -> (ProcessingPipeline, AdjustmentParams) {
    var pipeline = ProcessingPipeline()
    
    // 1. Translate adjustments
    let adjustments = AdjustmentParams(
        brightness: editPlan.adjustments.brightness,
        contrast: editPlan.adjustments.contrast,
        exposure: editPlan.adjustments.exposure,
        saturation: editPlan.adjustments.saturation,
        temperature: editPlan.adjustments.temperature,
        tint: editPlan.adjustments.tint,
        gamma: editPlan.adjustments.gamma
    )
    
    // 2. Translate operations to PipelineNodes
    for op in editPlan.operations {
        let processingOp = translateOperation(op)
        let node = PipelineNode(operation: processingOp, isEnabled: op.enabled)
        pipeline.addNode(node)
    }
    
    return (pipeline, adjustments)
}
```

## Security

- EditPlan is pure data (JSON). No executable code.
- All parameter values are bounded and validated before execution.
- Unknown operation types are rejected, not silently skipped.
- The executor never creates new shader types — it only selects from existing ProcessingOperation cases.

## Versioning Strategy

- `schemaVersion` is included in every EditPlan
- MetalCraft validates schemaVersion before processing
- Unknown versions are rejected with a clear error
- Backward compatibility: v1.1 should accept v1.0 plans (additive changes only)
