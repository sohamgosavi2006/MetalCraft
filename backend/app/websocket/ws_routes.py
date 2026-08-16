"""
FastAPI WebSocket route handlers for iOS client and Web Companion.
"""

import json
import logging
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from app.websocket.connection_manager import manager
from app.storage.database import DatabaseRepository
from app.telemetry.grafana_client import record_telemetry

logger = logging.getLogger("WebSocketRoutes")
ws_router = APIRouter()


@ws_router.websocket("/ws/ios")
async def websocket_ios_endpoint(
    websocket: WebSocket,
    sessionId: str = Query(default="global-ios-session")
):
    """WebSocket communication endpoint dedicated to connected MetalCraft iOS devices."""
    await manager.connect_ios(sessionId, websocket)
    try:
        while True:
            data_text = await websocket.receive_text()
            try:
                msg = json.loads(data_text)
                msg_type = msg.get("type", "").upper()
                gen_id = msg.get("generationId")

                logger.debug(f"[WebSocket] Received from iOS ({sessionId}): {msg_type}")

                if msg_type in ["PROGRESS_UPDATE", "METAL_RENDER_PROGRESS", "PROGRESS"]:
                    # Update database job record
                    if gen_id:
                        await DatabaseRepository.save_generation_job({
                            "generationId": gen_id,
                            "status": msg.get("status", "RENDERING"),
                            "progress": msg.get("progress", 0.0),
                            "progressMessage": msg.get("progressMessage", msg.get("message", "Rendering on Metal GPU")),
                            "currentFrame": msg.get("currentFrame", 0),
                            "totalFrames": msg.get("totalFrames", 0)
                        })
                    # Broadcast to Web UI
                    await manager.broadcast_to_web({
                        "type": "GENERATION_PROGRESS",
                        "generationId": gen_id,
                        "stage": msg.get("stage", "METAL_RENDERING"),
                        "status": msg.get("status", "RENDERING"),
                        "progress": msg.get("progress", 0.0),
                        "progressMessage": msg.get("progressMessage", msg.get("message", "")),
                        "currentFrame": msg.get("currentFrame", 0),
                        "totalFrames": msg.get("totalFrames", 0)
                    })

                elif msg_type in ["GENERATION_COMPLETED", "COMPLETED"]:
                    if gen_id:
                        artifact_data = msg.get("artifact", {})
                        if artifact_data:
                            await DatabaseRepository.save_video_artifact(artifact_data)
                        
                        await DatabaseRepository.save_generation_job({
                            "generationId": gen_id,
                            "artifactId": msg.get("artifactId", artifact_data.get("artifactId", f"artifact_{gen_id}")),
                            "status": "COMPLETED",
                            "progress": 1.0,
                            "progressMessage": "Production Ready",
                            "artifact": artifact_data,
                            "renderDurationSec": msg.get("renderDurationSec")
                        })
                        
                        # Record Audit Event
                        await DatabaseRepository.record_audit_event({
                            "category": "video",
                            "action": "Video Generation Completed",
                            "status": "SUCCESS",
                            "generationId": gen_id,
                            "artifactId": msg.get("artifactId"),
                            "description": f"MetalCraft iOS completed rendering on Metal GPU in {msg.get('renderDurationSec', 0.0):.2f}s."
                        })

                    await manager.broadcast_to_web({
                        "type": "GENERATION_COMPLETED",
                        "generationId": gen_id,
                        "status": "COMPLETED",
                        "artifact": msg.get("artifact"),
                        "renderDurationSec": msg.get("renderDurationSec")
                    })

                elif msg_type in ["GENERATION_FAILED", "FAILED"]:
                    if gen_id:
                        await DatabaseRepository.save_generation_job({
                            "generationId": gen_id,
                            "status": "FAILED",
                            "error": msg.get("error", "Unknown iOS render error")
                        })
                    await manager.broadcast_to_web({
                        "type": "GENERATION_FAILED",
                        "generationId": gen_id,
                        "status": "FAILED",
                        "error": msg.get("error")
                    })

                elif msg_type == "HEARTBEAT":
                    await DatabaseRepository.update_device_heartbeat(sessionId, "online")

                elif msg_type == "TELEMETRY":
                    event = msg.get("event", msg)
                    record_telemetry(event)
                    await DatabaseRepository.record_telemetry(event)
                    await manager.broadcast_to_web({
                        "type": "TELEMETRY_LOG",
                        "event": event
                    })

            except json.JSONDecodeError:
                logger.warning(f"[WebSocket] Invalid JSON received from iOS: {data_text}")

    except WebSocketDisconnect:
        manager.disconnect_ios(sessionId)
        await DatabaseRepository.update_device_heartbeat(sessionId, "offline")
        await manager.broadcast_to_web({
            "type": "DEVICE_STATUS_CHANGED",
            "deviceSessionId": sessionId,
            "status": "offline"
        })


@ws_router.websocket("/ws/web")
async def websocket_web_endpoint(websocket: WebSocket):
    """WebSocket communication endpoint for the Web Companion."""
    await manager.connect_web(websocket)
    try:
        # Initial greeting with active device connection state
        await websocket.send_text(json.dumps({
            "type": "CONNECTION_ESTABLISHED",
            "isIosConnected": manager.is_ios_connected(),
            "connectedDevicesCount": len(manager.active_ios_connections)
        }))

        while True:
            data = await websocket.receive_text()
            # Handle client-side pings or test dispatches
            pass
    except WebSocketDisconnect:
        manager.disconnect_web(websocket)
