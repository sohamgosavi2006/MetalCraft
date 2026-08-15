# Gemini Implementation Rules

> **Every Gemini implementation session MUST follow these rules.**

---

## Before Modifying Code

1. **Read the master plan**: `documentation/15_MASTER_GUIDES/IMPLEMENTATION_MASTER_PLAN.md`
2. **Read the relevant phase document** for the phase you are implementing
3. **Read the relevant architecture document** for the component you are modifying
4. **Inspect the actual repository** — confirm the described files still match reality
5. **Run existing tests** before starting: `xcodebuild test -scheme MetalCraft -destination 'platform=iOS Simulator,name=iPhone 17'`

## During Implementation

6. **Implement ONLY the requested phase** — do not implement future phases prematurely
7. **Preserve existing functionality** — never remove, replace, or unnecessarily rewrite working code
8. **Follow the existing code style** — observe the naming conventions, file organization, and patterns already in the codebase
9. **Create new files in the documented locations** — don't invent new directory structures
10. **Extend, don't replace** — prefer adding methods to existing services over creating replacement services

## After Implementation

11. **Run ALL tests**: `xcodebuild test -scheme MetalCraft -destination 'platform=iOS Simulator,name=iPhone 17'`
12. **Build for device**: `xcodebuild -scheme MetalCraft -destination 'id=00008030-001C088E0E2B402E' build`
13. **Report results** in the following format:

## Implementation Report Template

Every Gemini implementation response must include:

```markdown
## Phase X Implementation Report

### What Was Implemented
- [list of features/components implemented]

### Files Changed
| File | Action | Reason |
|------|--------|--------|
| path/to/file.swift | CREATED | [why] |
| path/to/file.swift | MODIFIED | [why] |

### Existing Functionality Preserved
- [confirm which existing features were verified as still working]

### Tests
- Existing tests: [PASSED / FAILED (details)]
- New tests added: [list]
- New tests: [PASSED / FAILED (details)]

### Known Limitations
- [any limitations or incomplete items]

### Deviations from Plan
- [any changes made that differ from the documented plan, with justification]

### Next Recommended Phase
- Phase [X+1]: [brief description]
```

## Absolute Prohibitions

- ❌ **NEVER** put API keys, secrets, or credentials in Swift source files or the public repository
- ❌ **NEVER** remove existing Metal shaders from `Shaders.metal`
- ❌ **NEVER** rewrite `MetalContext`, `MetalProcessor`, or `TexturePool`
- ❌ **NEVER** replace `AppState` — only extend it with new properties/methods
- ❌ **NEVER** modify `ProcessingPipeline` core mutation methods
- ❌ **NEVER** allow Gemini agent to directly access `MTLDevice`, `MTLTexture`, or `MTLCommandQueue`
- ❌ **NEVER** skip running tests after changes
- ❌ **NEVER** silently redesign architecture without documenting the deviation

## File Location Guide

| New Component | Location |
|--------------|----------|
| EditPlan models | `MetalCraft/Models/EditPlan.swift` |
| AgentState model | `MetalCraft/Models/AgentState.swift` |
| EditPlanExecutor | `MetalCraft/Services/EditPlanExecutor.swift` |
| AgentService | `MetalCraft/Services/AgentService.swift` |
| TelemetryService | `MetalCraft/Services/TelemetryService.swift` |
| AI Create views | `MetalCraft/Views/AICreate/` |
| Cloud agent | `cloud/agent/` (in hackathon repo) |
| MCP clients | `cloud/mcp/` (in hackathon repo) |
| Cloud deployment | `cloud/` (in hackathon repo) |

## Reference Documents

| Topic | Document |
|-------|----------|
| Existing architecture | `documentation/01_EXISTING_ARCHITECTURE/CURRENT_ARCHITECTURE.md` |
| Target architecture | `documentation/02_TARGET_ARCHITECTURE/TARGET_ARCHITECTURE.md` |
| EditPlan schema | `documentation/06_AGENTIC_AI/EDIT_PLAN.md` |
| Agent architecture | `documentation/06_AGENTIC_AI/AGENT_ARCHITECTURE.md` |
| Hackathon eligibility | `documentation/14_HACKATHON/ELIGIBILITY_RISK.md` |
| Master plan | `documentation/15_MASTER_GUIDES/IMPLEMENTATION_MASTER_PLAN.md` |
