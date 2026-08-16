"""
Project Metadata Synchronization API (/api/v1/projects).
"""

import json
from typing import Optional, Dict, Any, List
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from sqlalchemy import select, desc
from app.storage.database import async_session_factory
from app.storage.models import ProjectRecord

projects_router = APIRouter(prefix="/projects", tags=["Project Metadata"])


class UpsertProjectRequest(BaseModel):
    id: str
    name: str
    metadata: Dict[str, Any] = {}


@projects_router.get("")
async def list_projects():
    """Lists synchronized project metadata documents."""
    async with async_session_factory() as db:
        result = await db.execute(select(ProjectRecord).order_by(desc(ProjectRecord.updated_at)))
        records = list(result.scalars().all())
        projects = []
        for r in records:
            meta = {}
            if r.metadata_json:
                try:
                    meta = json.loads(r.metadata_json)
                except Exception:
                    pass
            projects.append({
                "id": r.id,
                "name": r.name,
                "metadata": meta,
                "createdAt": r.created_at.isoformat() if r.created_at else None,
                "updatedAt": r.updated_at.isoformat() if r.updated_at else None
            })
        return {"projects": projects, "totalCount": len(projects)}


@projects_router.post("")
async def upsert_project(request: UpsertProjectRequest):
    """Upserts project metadata record in backend persistent store."""
    async with async_session_factory() as db:
        result = await db.execute(select(ProjectRecord).where(ProjectRecord.id == request.id))
        record = result.scalar_one_or_none()
        if record:
            record.name = request.name
            record.metadata_json = json.dumps(request.metadata)
        else:
            record = ProjectRecord(
                id=request.id,
                name=request.name,
                metadata_json=json.dumps(request.metadata)
            )
            db.add(record)
        await db.commit()
        await db.refresh(record)
        return {"status": "saved", "projectId": record.id, "name": record.name}
