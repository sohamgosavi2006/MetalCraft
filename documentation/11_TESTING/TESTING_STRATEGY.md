# Testing Strategy

## Existing Tests

**File**: `MetalCraftTests/MetalCraftTests.swift` — 13 unit tests (ALL PASSING)

These tests cover:
- MetalContext initialization
- MetalProcessor shader dispatch
- ProcessingPipeline mutations
- AdjustmentParams Codable serialization
- ProcessingOperation encoding/decoding
- TextureLoader conversion
- Preset save/load

## Regression Policy

**RULE**: All 13 existing tests must pass after EVERY phase implementation.

```bash
# Run all tests
xcodebuild test -scheme MetalCraft -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Tests to Add Per Phase

### Phase 1: EditPlan Models
- [ ] EditPlan JSON round-trip (encode → JSON string → decode → equality)
- [ ] EditPlanOperation with various parameter types
- [ ] EditPlan with empty operations array
- [ ] Invalid schema version rejection
- [ ] AgentState enum raw values

### Phase 2: EditPlan Executor
- [ ] Valid plan → correct ProcessingPipeline
- [ ] Plan with adjustments → correct AdjustmentParams
- [ ] Plan with all 10 operation types
- [ ] Unknown operation type → error thrown
- [ ] Out-of-range parameters → error thrown
- [ ] Empty plan → empty pipeline (not error)
- [ ] Disabled operations → nodes with isEnabled=false

### Phase 3: Telemetry Service
- [ ] Event emission → buffer growth
- [ ] Flush → returns events and clears buffer
- [ ] Buffer max limit (100) → oldest events evicted
- [ ] Event serialization to JSON

### Phase 4: Agent Service
- [ ] Request encoding
- [ ] Response decoding (valid)
- [ ] Response decoding (malformed) → error
- [ ] Timeout handling

### Phase 7-8: Agent
- [ ] Agent produces valid EditPlan JSON
- [ ] Tool input validation
- [ ] Tool error handling
- [ ] Loop bounds enforced

## Integration Testing

### Manual Test Checklist

After each phase, verify:

**Editor (existing)**:
- [ ] Import image from Photos
- [ ] Apply adjustments (brightness, contrast, exposure)
- [ ] Apply effects (grayscale, blur, sharpen)
- [ ] Add to pipeline, reorder, toggle enable/disable
- [ ] Undo/redo
- [ ] Apply preset
- [ ] Comparison modes (Original, Processed, Side-by-Side, Split)
- [ ] Export image

**Video (existing)**:
- [ ] Import video from Photos
- [ ] Play/pause/seek
- [ ] Apply same effects to video
- [ ] Correct orientation (not flipped/rotated)
- [ ] Export video

**Projects (existing)**:
- [ ] Create project
- [ ] Add images and videos
- [ ] Open project image → loads pipeline
- [ ] Open project video → loads pipeline
- [ ] Delete project

**AI Create (Phase 5+)**:
- [ ] Type prompt and send
- [ ] See agent state transitions
- [ ] See EditPlan preview
- [ ] Approve → applies to editor
- [ ] Switch to Editor tab → see applied effects
