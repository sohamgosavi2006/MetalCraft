"""
Real-time WebSocket connection manager for MetalCraft Render backend.
Manages connections from iOS devices and Web UI clients, broadcasting generation progress,
commands, and telemetry events with reconnection recovery.
"""

import json
import logging
from typing import Dict, List, Set, Optional, Any
from fastapi import WebSocket
from app.storage.database import DatabaseRepository

logger = logging.getLogger("ConnectionManager")


class ConnectionManager:
    def __init__(self):
        # Maps deviceSessionId -> WebSocket connection
        self.active_ios_connections: Dict[str, WebSocket] = {}
        # Set of active web client WebSockets
        self.active_web_connections: Set[WebSocket] = set()
        # Maps generationId -> set of interested WebSockets
        self.generation_subscribers: Dict[str, Set[WebSocket]] = {}
        # Pending job queue for offline devices
        self.pending_jobs_by_device: Dict[str, List[Dict[str, Any]]] = {}

    async def connect_ios(self, session_id: str, websocket: WebSocket):
        """Registers an active iOS device WebSocket connection."""
        await websocket.accept()
        self.active_ios_connections[session_id] = websocket
        logger.info(f"[WebSocket] iOS device connected: {session_id} (Total iOS: {len(self.active_ios_connections)})")
        
        # Broadcast device online event to Web clients
        await self.broadcast_to_web({
            "type": "DEVICE_STATUS_CHANGED",
            "deviceSessionId": session_id,
            "status": "online"
        })
        
        # Flush any pending jobs queued while device was offline
        if session_id in self.pending_jobs_by_device:
            pending = self.pending_jobs_by_device.pop(session_id)
            for job in pending:
                logger.info(f"[WebSocket] Dispatched queued job {job.get('generationId')} to reconnected iOS device {session_id}")
                await websocket.send_text(json.dumps(job))

    def disconnect_ios(self, session_id: str):
        """Removes a disconnected iOS device."""
        if session_id in self.active_ios_connections:
            del self.active_ios_connections[session_id]
            logger.info(f"[WebSocket] iOS device disconnected: {session_id}")

    async def connect_web(self, websocket: WebSocket):
        """Registers an active Web UI WebSocket client."""
        await websocket.accept()
        self.active_web_connections.add(websocket)
        logger.info(f"[WebSocket] Web client connected (Total Web: {len(self.active_web_connections)})")

    def disconnect_web(self, websocket: WebSocket):
        """Removes a disconnected Web UI client."""
        self.active_web_connections.discard(websocket)
        for gen_id in list(self.generation_subscribers.keys()):
            self.generation_subscribers[gen_id].discard(websocket)
            if not self.generation_subscribers[gen_id]:
                del self.generation_subscribers[gen_id]

    async def send_to_ios(self, session_id: str, message: Dict[str, Any]) -> bool:
        """Sends a structured command to a specific iOS device or queues if offline."""
        if session_id in self.active_ios_connections:
            ws = self.active_ios_connections[session_id]
            await ws.send_text(json.dumps(message))
            return True
        else:
            # Fallback: if single iOS device is connected, dispatch to it
            if self.active_ios_connections:
                active_ws = next(iter(self.active_ios_connections.values()))
                await active_ws.send_text(json.dumps(message))
                return True
            else:
                # Queue job until device reconnects
                if session_id not in self.pending_jobs_by_device:
                    self.pending_jobs_by_device[session_id] = []
                self.pending_jobs_by_device[session_id].append(message)
                logger.info(f"[WebSocket] iOS device {session_id} offline; queued command {message.get('type')}")
                return False

    async def broadcast_to_web(self, message: Dict[str, Any]):
        """Broadcasts event to all active Web UI clients."""
        payload_str = json.dumps(message)
        dead_connections = []
        for ws in self.active_web_connections:
            try:
                await ws.send_text(payload_str)
            except Exception:
                dead_connections.append(ws)
        for dead in dead_connections:
            self.active_web_connections.discard(dead)

    async def broadcast_generation_update(self, generation_id: str, message: Dict[str, Any]):
        """Broadcasts progress update for a specific generationId to all subscribers and Web clients."""
        message["generationId"] = generation_id
        await self.broadcast_to_web(message)

    def is_ios_connected(self, session_id: Optional[str] = None) -> bool:
        """Returns True if the specified iOS device (or any iOS device) is actively connected."""
        if session_id:
            return session_id in self.active_ios_connections
        return len(self.active_ios_connections) > 0


manager = ConnectionManager()
