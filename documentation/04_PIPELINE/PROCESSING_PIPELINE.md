# Processing Pipeline Architecture

## Overview

The ProcessingPipeline is MetalCraft's non-destructive editing model. It represents an ordered list of processing operations (PipelineNodes) that are applied sequentially to an input texture.

## Data Model

```
ProcessingPipeline
    │
    ├── nodes: [PipelineNode]
    │       ├── PipelineNode
    │       │   ├── id: UUID
    │       │   ├── operation: ProcessingOperation
    │       │   └── isEnabled: Bool
    │       │
    │       ├── PipelineNode
    │       │   ├── id: UUID
    │       │   ├── operation: .gaussianBlur(sigma: 2.5)
    │       │   └── isEnabled: true
    │       │
    │       └── PipelineNode
    │           ├── id: UUID
    │           ├── operation: .sobelEdge(strength: 1.0, blend: 0.5)
    │           └── isEnabled: false  (disabled — skipped during processing)
    │
    └── enabledNodes: [PipelineNode]  (computed — only enabled nodes)
```

## Processing Execution

```
Input MTLTexture (originalTexture)
    │
    ▼
For each enabledNode in pipeline.enabledNodes:
    │
    ├── TexturePool.acquire(matching input size)
    │
    ├── MetalProcessor.process(
    │       operation: node.operation,
    │       input: currentTexture,
    │       output: outputTexture
    │   )
    │
    └── currentTexture = outputTexture
    │
    ▼
Final MTLTexture (processedTexture)
```

## Adjustments vs Pipeline

**Adjustments** (AdjustmentParams) are always applied as the FIRST operation, regardless of pipeline ordering. This is because photographic adjustments (brightness, contrast, exposure, etc.) affect the base look before creative effects.

```
Input Texture
    │
    ▼
adjustments_kernel (AdjustmentParams)  ← Always first
    │
    ▼
Pipeline Node 1 (e.g., gaussianBlur)
    │
    ▼
Pipeline Node 2 (e.g., sobelEdge)
    │
    ▼
Output Texture
```

## Undo/Redo

AppState maintains undo/redo stacks of ProcessingPipeline snapshots:
- `undoStack: [ProcessingPipeline]` (max 50)
- `redoStack: [ProcessingPipeline]`
- `pushUndoState()` — saves current pipeline before mutation
- `undo()` — pops from undoStack, pushes to redoStack
- `redo()` — pops from redoStack, pushes to undoStack

## Presets

A Preset is a named snapshot of (ProcessingPipeline + AdjustmentParams). Applying a preset replaces the current pipeline and adjustments entirely.

## EditPlan Integration

The EditPlanExecutor translates an EditPlan into a ProcessingPipeline:
1. Clear current pipeline
2. For each EditPlan operation, create a PipelineNode with the corresponding ProcessingOperation
3. Set AdjustmentParams from EditPlan adjustments
4. Trigger reprocessing
