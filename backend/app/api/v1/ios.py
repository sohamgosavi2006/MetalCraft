"""
iOS Device Registration, Heartbeat, and Command Delivery API (/api/v1/ios).
"""

from fastapi import APIRouter, HTTPException
from typing import List, Dict, Any
from app.agents.schemas import DeviceRegistrationRequest, DeviceHeartbeatRequest
from app.storage.database import DatabaseRepository
from app.websocket.connection_manager import manager

ios_router = APIRouter(prefix="/ios", tags=["iOS Device Management"])


@ios_router.post("/register")
async def register_device(request: DeviceRegistrationRequest):
    """Registers a MetalCraft iOS client instance and stores device capabilities."""
    session = await DatabaseRepository.upsert_device_session(
        session_id=request.deviceSessionId,
        device_name=request.deviceName,
        model=request.model,
        os_version=request.osVersion,
        app_version=request.appVersion,
        capabilities=request.capabilities.model_dump()
    )
    
    # Broadcast registration event to Web UI
    await manager.broadcast_to_web({
        "type": "DEVICE_REGISTERED",
        "deviceSessionId": request.deviceSessionId,
        "deviceName": request.deviceName,
        "model": request.model,
        "capabilities": request.capabilities.model_dump()
    })

    return {
        "status": "registered",
        "deviceSessionId": session.session_id,
        "assignedEndpoint": "/ws/ios",
        "backendVersion": "1.0.0"
    }


@ios_router.post("/heartbeat")
async def receive_heartbeat(request: DeviceHeartbeatRequest):
    """Updates device presence timestamp and active state."""
    session = await DatabaseRepository.update_device_heartbeat(
        session_id=request.deviceSessionId,
        status=request.status
    )
    if not session:
        raise HTTPException(status_code=404, detail="Device session not found. Please register first.")
    
    return {
        "status": "acknowledged",
        "deviceSessionId": request.deviceSessionId,
        "timestamp": request.timestamp.isoformat()
    }


@ios_router.get("/devices")
async def list_devices():
    """Lists all registered iOS devices and their connection status."""
    devices = await DatabaseRepository.list_active_devices()
    result = []
    for d in devices:
        is_ws_active = manager.is_ios_connected(d.session_id)
        result.append({
            "sessionId": d.session_id,
            "name": d.device_name,
            "model": d.model,
            "osVersion": d.os_version,
            "appVersion": d.app_version,
            "isLive": is_ws_active,
            "status": "online" if is_ws_active else d.status,
            "lastHeartbeat": d.last_heartbeat.isoformat() if d.last_heartbeat else None
        })
    return {"devices": result, "totalCount": len(result)}
