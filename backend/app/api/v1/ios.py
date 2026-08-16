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
        "capabilities": request.capabilities.model_dump(),
        "isIosConnected": True,
        "connectedCount": max(1, len(manager.active_ios_connections))
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
        # Auto-upsert device if not yet in database
        session = await DatabaseRepository.upsert_device_session(
            session_id=request.deviceSessionId,
            device_name="MetalCraft iPhone",
            model="iPhone (Apple Silicon)",
            os_version="iOS 18",
            app_version="1.0.0",
            capabilities={"metal": True, "videoRendering": True, "photosAccess": True}
        )
    
    # Broadcast heartbeat update to Web UI
    await manager.broadcast_to_web({
        "type": "DEVICE_HEARTBEAT",
        "deviceSessionId": request.deviceSessionId,
        "status": request.status,
        "isIosConnected": True,
        "connectedCount": max(1, len(manager.active_ios_connections))
    })
    
    return {
        "status": "acknowledged",
        "deviceSessionId": request.deviceSessionId,
        "timestamp": request.timestamp.isoformat()
    }


@ios_router.get("/devices")
async def list_devices():
    """Lists all registered iOS devices and their connection status."""
    import json
    from datetime import datetime, timedelta
    devices = await DatabaseRepository.list_active_devices()
    result = []
    now = datetime.utcnow()
    for d in devices:
        is_ws_active = manager.is_ios_connected(d.session_id)
        is_recent_heartbeat = False
        if d.last_heartbeat:
            diff = (now - d.last_heartbeat).total_seconds()
            if diff <= 45:
                is_recent_heartbeat = True
        
        is_online = is_ws_active or is_recent_heartbeat
        capabilities = {}
        if d.capabilities_json:
            try:
                capabilities = json.loads(d.capabilities_json)
            except Exception:
                pass
        
        display_status = "ONLINE" if is_online else "OFFLINE"
        clean_id = d.session_id.replace("MC-IOS-", "").replace("-", "")[:8].upper()
        
        result.append({
            "sessionId": d.session_id,
            "deviceId": d.session_id if d.session_id.startswith("MC-IOS-") else f"MC-IOS-{clean_id}",
            "name": d.device_name,
            "model": d.model,
            "osVersion": d.os_version,
            "appVersion": d.app_version,
            "capabilities": capabilities,
            "isLive": is_online,
            "status": display_status,
            "lastHeartbeat": d.last_heartbeat.isoformat() if d.last_heartbeat else None,
            "createdAt": d.created_at.isoformat() if d.created_at else None
        })
    return {"devices": result, "totalCount": len(result)}


@ios_router.get("/devices/{sessionId}")
async def get_device_details(sessionId: str):
    """Retrieves full operational diagnostics and job history for a specific device."""
    import json
    devices = await DatabaseRepository.list_active_devices()
    device = next((d for d in devices if d.session_id == sessionId), None)
    if not device:
        raise HTTPException(status_code=404, detail=f"Device '{sessionId}' not found.")
    
    is_ws_active = manager.is_ios_connected(device.session_id)
    capabilities = {}
    if device.capabilities_json:
        try:
            capabilities = json.loads(device.capabilities_json)
        except Exception:
            pass

    clean_id = device.session_id.replace("-", "")[:8].upper()
    recent_jobs = await DatabaseRepository.list_generation_jobs(limit=20)
    audit_events = await DatabaseRepository.list_audit_events(limit=20)

    return {
        "device": {
            "sessionId": device.session_id,
            "deviceId": f"MC-IOS-{clean_id}",
            "name": device.device_name,
            "model": device.model,
            "osVersion": device.os_version,
            "appVersion": device.app_version,
            "capabilities": capabilities,
            "isLive": is_ws_active,
            "status": "ONLINE" if is_ws_active else "OFFLINE",
            "lastHeartbeat": device.last_heartbeat.isoformat() if device.last_heartbeat else None,
            "createdAt": device.created_at.isoformat() if device.created_at else None
        },
        "recentJobs": [
            {
                "generationId": j.generation_id,
                "status": j.status,
                "progress": j.progress,
                "progressMessage": j.progress_message,
                "renderDurationSec": j.render_duration_sec,
                "createdAt": j.created_at.isoformat() if j.created_at else None
            } for j in recent_jobs
        ],
        "recentAudit": [
            {
                "action": a.action,
                "category": a.category,
                "status": a.status,
                "description": a.description,
                "timestamp": a.timestamp.isoformat() if a.timestamp else None
            } for a in audit_events
        ]
    }
