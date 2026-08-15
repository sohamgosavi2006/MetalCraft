# Hackathon Eligibility Risk Analysis

> **IMPORTANT**: This document analyzes eligibility risks for the Agentic Cinema hackathon. It does NOT make legal determinations. All items are labeled FACT, INFERENCE, RISK, or RECOMMENDATION.

---

## Hackathon Rules Summary

**FACT**: The Agentic Cinema hackathon (https://agentic-cinema.devpost.com/) requires:
1. Projects must be **newly created during the contest period**
2. Projects **cannot be a modification or extension of existing work**
3. Must use **Gemini** and **Google Cloud Agent Builder/ADK**
4. Must integrate a **Partner Entity's MCP server** for a real media/entertainment workflow
5. AI/agent tooling restricted to **Google Cloud AI** and the relevant partner's AI capabilities

---

## Current MetalCraft Repository Status

**FACT**: The MetalCraft repository at https://github.com/sohamgosavi2006/MetalCraft.git contains:
- A fully implemented iOS image editor with Metal GPU processing
- A fully implemented video editor with AVFoundation + Metal integration
- A project management system with multi-image/video support
- An analytics dashboard with GPU benchmarking
- 13 passing unit tests
- Multiple development iterations visible in commit history

**FACT**: The repository has commit history predating the contest period.

**FACT**: The AI Create tab is currently a placeholder ("Coming Soon") — the agentic functionality does not yet exist in the repository.

---

## Risk Analysis

### RISK 1 — Existing Repository May Be Ineligible (SEVERITY: HIGH)

**INFERENCE**: Submitting the existing MetalCraft repository as-is with agentic features added on top could be interpreted as "modification or extension of existing work," which the rules explicitly prohibit.

**PROBABILITY**: HIGH — The commit history clearly shows pre-contest development.

**MITIGATION OPTIONS**:

#### Option A: New Repository (RECOMMENDED)
Create a **new GitHub repository** during the contest period that contains only the contest-period work. Reference MetalCraft as prior art / inspiration but ensure the submitted project is freshly created.

#### Option B: Separate Agentic Project
Create a new project called e.g., "MetalCraft-Agentic" or "MetalCraft-Cinema" that focuses entirely on the agentic pipeline (cloud agent + MCP integrations + EditPlan + telemetry) and uses MetalCraft as a documented "platform" / "runtime" that the agent controls.

#### Option C: Fork with Clean History
Fork MetalCraft into a new repository with a clean commit history starting within the contest period. **RISK**: This may still be seen as derivative work.

### RISK 2 — Prior Art Disclosure (SEVERITY: MEDIUM)

**RECOMMENDATION**: If submitting, explicitly disclose in the Devpost submission:
- "The Metal GPU processing engine was developed as a personal learning project prior to the contest"
- "All agentic AI functionality, Gemini integration, Google Cloud deployment, Grafana MCP integration, Parallel MCP integration, EditPlan system, and agent-to-editor architecture were created during the contest period"

### RISK 3 — Partner Track Selection (SEVERITY: MEDIUM)

**FACT**: The planned partner integrations are Grafana (primary) and Parallel (secondary).

**INFERENCE**: The submission must choose ONE partner track. Using both partners is fine, but the submission track should be for the primary partner (Grafana).

**RECOMMENDATION**: Submit under the **Grafana** partner track. Document Parallel as an additional value-add integration.

---

## Recommended Strategy

### RECOMMENDATION: Create a New Hackathon Repository

1. Create a new repository (e.g., `metalcraft-agentic-cinema`) during the contest period
2. The new repository should contain:
   - The Google Cloud agent (Python/ADK) — **100% new**
   - The Grafana MCP integration — **100% new**
   - The Parallel MCP integration — **100% new**
   - The EditPlan schema and executor — **100% new**
   - The iOS AgentService (iOS ↔ Cloud communication) — **100% new**
   - The TelemetryService (iOS → Grafana) — **100% new**
   - The AI Create UI — **100% new**
   - Cloud Run deployment configuration — **100% new**
3. Reference MetalCraft as the "Metal GPU runtime" that the agent controls
4. Clearly document what is new vs what is prior art
5. All commit history in the new repository is within the contest period

### What Constitutes "New Work" for the Hackathon

| Component | New? | Justification |
|-----------|------|--------------|
| Gemini agent with tool definitions | ✅ NEW | Core hackathon requirement |
| Google Cloud ADK deployment | ✅ NEW | Core hackathon requirement |
| Grafana MCP integration | ✅ NEW | Primary partner integration |
| Parallel MCP integration | ✅ NEW | Secondary partner integration |
| EditPlan schema + validation | ✅ NEW | AI-to-editor contract |
| EditPlanExecutor | ✅ NEW | Translates AI decisions to GPU pipeline |
| AgentService (iOS networking) | ✅ NEW | iOS ↔ Cloud communication |
| TelemetryService (iOS → Grafana) | ✅ NEW | Processing observability |
| AI Create UI | ✅ NEW | Agentic creative interface |
| Agent feedback loop | ✅ NEW | Observe → Reason → Act → Evaluate |
| Cloud Run infrastructure | ✅ NEW | Deployment |
| Secret Manager configuration | ✅ NEW | Security |
| Metal GPU processing engine | ❌ PRIOR ART | Developed before contest |
| Image/Video editor UI | ❌ PRIOR ART | Developed before contest |
| Project management system | ❌ PRIOR ART | Developed before contest |

---

## Devpost Submission Checklist

- [ ] New repository created during contest period
- [ ] All commits within contest period
- [ ] Gemini + Google Cloud AI demonstrated
- [ ] Partner MCP (Grafana) integrated and functional
- [ ] Demo video showing agent workflow end-to-end
- [ ] Devpost project page with:
  - [ ] Project description
  - [ ] Technology stack
  - [ ] How it was built
  - [ ] What it does
  - [ ] Challenges faced
  - [ ] Accomplishments
  - [ ] What's next
  - [ ] Built with (technologies)
  - [ ] Try it out (links)
- [ ] Source code link (new repository)
- [ ] Prior art explicitly disclosed
- [ ] License compliant

---

## Demo Script Outline

1. **Opening**: Show MetalCraft app with image/video loaded
2. **AI Create**: User types creative prompt ("Make this cinematic with warm golden-hour tones")
3. **Agent Reasoning**: Show agent analyzing media metadata, consulting Parallel for cinematography trends
4. **EditPlan Generation**: Show the structured EditPlan the agent produced
5. **GPU Execution**: MetalCraft applies the EditPlan via Metal compute shaders — real GPU processing, not simulated
6. **Grafana Observability**: Show Grafana dashboard with processing telemetry
7. **Agent Evaluation**: Agent evaluates result via Grafana metrics, suggests refinement
8. **Revision**: Agent revises EditPlan, MetalCraft re-processes
9. **Final Output**: User approves and exports final image/video
10. **Architecture Summary**: Brief architecture diagram showing Gemini → EditPlan → MetalCraft → Metal GPU → Grafana → Agent loop
