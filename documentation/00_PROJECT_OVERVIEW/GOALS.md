# Goals

## G1 — Preserve Existing Functionality
All currently implemented image editing, video editing, Metal GPU processing, project management, analytics, presets, undo/redo, comparison modes, and export must continue working without regression.

## G2 — Agentic Creative Director
Gemini must act as a Creative Director that understands user intent, analyzes media context, and generates structured EditPlans that MetalCraft can execute.

## G3 — Structured EditPlan Contract
All AI-to-editor communication must flow through a validated, versioned EditPlan JSON schema — never arbitrary code execution.

## G4 — Partner MCP Integration
Integrate Grafana MCP (primary partner) for production observability and Parallel MCP (secondary) for external creative research.

## G5 — Agentic Feedback Loop
The agent must observe processing results via Grafana telemetry, evaluate outcomes, and revise EditPlans when necessary.

## G6 — On-Device GPU Processing
All heavy media processing (image filters, video frame rendering, export) must remain on the iPhone GPU via Apple Metal. Cloud receives only metadata/prompts.

## G7 — Hackathon Compliance
Meet all Agentic Cinema hackathon requirements for Gemini + Google Cloud + Partner MCP integration.
