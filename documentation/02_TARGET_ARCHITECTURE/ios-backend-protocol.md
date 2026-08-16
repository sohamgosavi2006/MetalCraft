# MetalCraft — iOS ↔ Render Backend Communication Protocol

## 1. Overview
The communication protocol between the MetalCraft iOS client and Render Cloud uses dual-channel HTTPS and WebSocket interfaces.

---

## 2. HTTPS REST API (`/api/v1/`)

### Device Registration & Presence
- **`POST /api/v1/ios/register`**:
  - Request: `deviceSessionId`, `deviceName`, `model`, `osVersion`, `capabilities` (`metal: true`, `videoRendering: true`, etc.).
  - Response: `{ "status": "registered", "assignedEndpoint": "/ws/ios" }`.
- **`POST /api/v1/ios/heartbeat`**:
  - Sent every 15 seconds to maintain online device status.

### Creative Planning & Jobs
- **`POST /api/v1/agent/create`**:
  - Ingests creative prompt and project media metadata.
  - Returns structured `EditPlan` and `AudioPlan` synthesized by Gemini 2.5 Flash.
- **`POST /api/v1/generations`**:
  - Creates a new generation job with a trace `generationId`.
  - Dispatches execution command to connected iPhone over WebSocket.

---

## 3. Real-Time WebSocket Protocol (`/ws/ios`)

### Message Types Sent from Cloud to iOS:
```json
{
  "type": "EXECUTE_GENERATION_JOB",
  "generationId": "gen_94a2b1c0",
  "artifactId": "artifact_video_18df3a",
  "projectName": "Cinematic Reel",
  "plan": { ... }
}
```

### Message Types Sent from iOS to Cloud:
1. **Progress Update**:
```json
{
  "type": "PROGRESS_UPDATE",
  "generationId": "gen_94a2b1c0",
  "stage": "METAL_RENDERING",
  "progress": 0.62,
  "currentFrame": 279,
  "totalFrames": 450,
  "progressMessage": "Rendering scene 2 of 3 on Apple Metal GPU"
}
```

2. **Generation Completed**:
```json
{
  "type": "GENERATION_COMPLETED",
  "generationId": "gen_94a2b1c0",
  "artifactId": "artifact_video_18df3a",
  "renderDurationSec": 2.45,
  "artifact": {
    "artifactId": "artifact_video_18df3a",
    "generationId": "gen_94a2b1c0",
    "duration": 15.0,
    "width": 1080,
    "height": 1920,
    "fileSize": 12458900,
    "formattedFileSize": "11.88 MB",
    "validationStatus": "VALIDATED"
  }
}
```
