"""
Audit Logging and Compliance API (/api/v1/audit).
"""

from typing import Optional, Dict, Any, List
from fastapi import APIRouter, Query
from pydantic import BaseModel
from app.agents.schemas import AuditEvent
from app.storage.database import DatabaseRepository

audit_router = APIRouter(prefix="/audit", tags=["Audit Log"])


@audit_router.get("")
async def get_audit_records(
    limit: int = Query(default=100, le=500),
    category: Optional[str] = Query(default=None)
):
    """Retrieves chronological audit events with filtering by category."""
    events = await DatabaseRepository.list_audit_events(limit=limit, category=category)
    result = []
    for e in events:
        result.append({
            "id": e.id,
            "timestamp": e.timestamp.isoformat() if e.timestamp else None,
            "category": e.category,
            "action": e.action,
            "status": e.status,
            "projectId": e.project_id,
            "projectName": e.project_name,
            "generationId": e.generation_id,
            "artifactId": e.artifact_id,
            "mediaType": e.media_type,
            "description": e.description,
            "source": e.source
        })
    return {"auditRecords": result, "totalCount": len(result)}


@audit_router.post("")
async def create_audit_record(event: AuditEvent):
    """Ingests an audit record from the iOS client or cloud pipeline."""
    record = await DatabaseRepository.record_audit_event(event.model_dump())
    return {"status": "recorded", "id": record.id}
