# Risk Register

| ID | Risk | Severity | Probability | Impact | Mitigation | Detection | Fallback |
|----|------|----------|------------|--------|-----------|-----------|----------|
| R01 | Existing functionality regression | HIGH | MEDIUM | Editor/video stops working | Run all 13 tests after every change. Manual regression checklist. | Test failure, app crash | Revert to last known-good commit |
| R02 | Video memory pressure | HIGH | MEDIUM | App crash on large videos | TexturePool reuse, proxy resolution for preview, frame-by-frame processing | Memory warning notifications | Reduce preview resolution, process fewer frames |
| R03 | Metal resource lifetime | HIGH | LOW | GPU crash, undefined behavior | Never recycle texture while command buffer in-flight. Use completion handlers. | Metal validation layer, GPU crash reports | Restart processing pipeline |
| R04 | GPU/CPU synchronization | MEDIUM | LOW | Race conditions, corrupted textures | Use MTLCommandBuffer completion handlers. @MainActor for UI. | Visual artifacts, test failures | Add synchronization barriers |
| R05 | Video encoding failures | MEDIUM | MEDIUM | Export fails | Handle AVAssetWriter errors, validate codec support | AVAssetWriter error callbacks | Retry with different settings, show error to user |
| R06 | Audio synchronization | MEDIUM | LOW | Audio/video desync in export | Preserve audio track timing, use CMTime precisely | Playback review | Re-encode with audio |
| R07 | Network failure (agent) | HIGH | HIGH | AI Create non-functional | Timeout handling (30s), retry logic, offline fallback message | URLSession errors | "AI features require internet connection" message |
| R08 | Gemini API failure | HIGH | MEDIUM | Agent cannot reason | Retry with exponential backoff, circuit breaker | API error responses | Show error, suggest manual editing |
| R09 | Parallel MCP failure | MEDIUM | MEDIUM | No creative research | Timeout (10s), fallback to no-research mode | MCP error response | Agent proceeds without research context |
| R10 | Grafana MCP failure | MEDIUM | MEDIUM | No observability data | Timeout (10s), fallback to local telemetry only | MCP error response | Agent skips observability step |
| R11 | Agent infinite loops | HIGH | LOW | Agent never terminates | Max 3 iterations, 60s total timeout | Iteration counter | Force COMPLETED with best result |
| R12 | Hallucinated EditPlans | HIGH | MEDIUM | Invalid operations, crashes | Strict schema validation, reject unknown operation types | Validation errors | Return validation error to agent for retry |
| R13 | Unsafe tool calls | HIGH | LOW | Security breach, data leak | Tool authorization, input validation, no direct GPU access | Audit logging | Reject unauthorized tool calls |
| R14 | Prompt injection | MEDIUM | LOW | Agent behaves maliciously | Sanitize user input, separate system/user prompts, validate outputs | Output monitoring | Reject suspicious EditPlans |
| R15 | Credential leakage | CRITICAL | LOW | API keys exposed | Secret Manager only, no keys in code/repo, .gitignore | Pre-commit hooks, code review | Rotate compromised keys immediately |
| R16 | Media privacy | HIGH | LOW | User media uploaded without consent | LOCAL ONLY by default, explicit consent for thumbnails | Privacy audit | Remove cloud media storage |
| R17 | Cloud costs | MEDIUM | MEDIUM | Unexpected billing | Rate limiting, bounded agent loops, minimize Gemini calls | Cost monitoring alerts | Reduce model size, add quotas |
| R18 | API latency | MEDIUM | HIGH | Slow agent response | Streaming responses, progress indicators, timeouts | Response time monitoring | Show "processing" UI, allow cancel |
| R19 | iOS permissions denied | MEDIUM | MEDIUM | Photos save fails | Permission request flow, handle denied/limited states | PHAuthorizationStatus check | Show settings redirect, manual share |
| R20 | Hackathon eligibility | HIGH | MEDIUM | Disqualification | New repository for contest, disclose prior art | Rules review | Separate repositories clearly |
| R21 | Partner track compliance | MEDIUM | LOW | Wrong track submission | Grafana as primary, verify MCP usage requirements | Rules review | Adjust submission to match requirements |
| R22 | Unsupported media formats | LOW | LOW | Import fails | Validate format before processing | Error handling | Show supported formats list |
