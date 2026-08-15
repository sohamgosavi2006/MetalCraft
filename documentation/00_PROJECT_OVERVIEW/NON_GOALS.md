# Non-Goals

## NG1 — Not a Full Cloud Video Editor
MetalCraft is NOT a cloud-based video editing platform. Heavy media processing stays on-device.

## NG2 — Not Arbitrary AI Code Execution
Gemini must NOT directly generate or execute arbitrary Metal shader code, Swift code, or have unrestricted access to MTLDevice/MTLTexture.

## NG3 — Not a Rebuild
The existing Metal pipeline, project system, and editor are NOT to be rebuilt from scratch. Extend, don't replace.

## NG4 — Not a ChatGPT Wrapper
AI Create is NOT simply a chat interface that returns text. It must produce actionable EditPlans that drive actual GPU processing.

## NG5 — Not Unsupported Hardware Metrics
Do NOT invent iOS hardware metrics that are unavailable through public APIs. Clearly distinguish AVAILABLE vs ESTIMATED vs NOT AVAILABLE.

## NG6 — Not Full Media Upload
Do NOT upload full-resolution images/videos to cloud services unless explicitly required and user-consented. Send metadata, thumbnails, or analysis results instead.
