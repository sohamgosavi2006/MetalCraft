"""
Project Metadata & Media Synchronization API (/api/v1/projects).
Persists multi-asset project documents, adjustments, soundtracks, and media files.
"""

import json
from typing import Optional, Dict, Any, List
from datetime import datetime
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select, desc
from app.storage.database import async_session_factory
from app.storage.models import ProjectRecord

projects_router = APIRouter(prefix="/projects", tags=["Project Metadata"])

# Seed projects data for initial store
DEFAULT_PROJECTS = [
    {
        "id": "proj-1",
        "name": "MetalCraft Soham",
        "isFavorite": True,
        "createdAt": "2026-08-16T00:00:00Z",
        "updatedAt": "2026-08-16T00:33:00Z",
        "aspectRatio": "9:16",
        "targetDurationSec": 15.0,
        "soundtrack": {
            "title": "Neon Highway Drift",
            "tempoBpm": 124,
            "genre": "Synthwave",
            "durationSec": 15.0
        },
        "photos": [
            {
                "id": "media-1",
                "name": "Tokyo Cyberpunk Alley",
                "aspect": "9:16",
                "url": "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=800&q=80",
                "thumb": "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=200&q=80",
                "adjustments": {"brightness": 0.0, "contrast": 1.15, "exposure": 0.1, "saturation": 1.25, "temperature": -0.15, "vignette": 15}
            },
            {
                "id": "media-2",
                "name": "Golden Hour Coastline",
                "aspect": "9:16",
                "url": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80",
                "thumb": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=200&q=80",
                "adjustments": {"brightness": 0.05, "contrast": 1.05, "exposure": 0.0, "saturation": 1.1, "temperature": 0.35, "vignette": 0}
            },
            {
                "id": "media-3",
                "name": "Studio Portrait Silhouette",
                "aspect": "9:16",
                "url": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=80",
                "thumb": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&q=80",
                "adjustments": {"brightness": -0.1, "contrast": 1.3, "exposure": -0.05, "saturation": 0.9, "temperature": 0.0, "vignette": 25}
            },
            {
                "id": "media-4",
                "name": "Minimalist Architecture",
                "aspect": "9:16",
                "url": "https://images.unsplash.com/photo-1513694203232-719a280e022f?w=800&q=80",
                "thumb": "https://images.unsplash.com/photo-1513694203232-719a280e022f?w=200&q=80",
                "adjustments": {"brightness": 0.0, "contrast": 1.1, "exposure": 0.05, "saturation": 0.95, "temperature": -0.05, "vignette": 0}
            },
            {
                "id": "media-6",
                "name": "Product Bottle Hero Shot",
                "aspect": "9:16",
                "url": "https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=800&q=80",
                "thumb": "https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=200&q=80",
                "adjustments": {"brightness": 0.0, "contrast": 1.2, "exposure": 0.0, "saturation": 1.05, "temperature": 0.0, "vignette": 10}
            }
        ],
        "videos": [
            {
                "id": "media-5",
                "name": "High Pacing City Drift",
                "aspect": "9:16",
                "durationSec": 15.0,
                "url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
                "thumb": "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=200&q=80"
            }
        ]
    },
    {
        "id": "proj-2",
        "name": "Cyberpunk Reel 2026",
        "isFavorite": True,
        "createdAt": "2026-08-15T18:00:00Z",
        "updatedAt": "2026-08-15T20:45:00Z",
        "aspectRatio": "9:16",
        "targetDurationSec": 15.0,
        "soundtrack": {
            "title": "Night City Pulse",
            "tempoBpm": 128,
            "genre": "Cyberpunk",
            "durationSec": 15.0
        },
        "photos": [
            {
                "id": "media-1",
                "name": "Tokyo Cyberpunk Alley",
                "aspect": "9:16",
                "url": "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=800&q=80",
                "thumb": "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=200&q=80",
                "adjustments": {"brightness": 0.0, "contrast": 1.3, "exposure": 0.0, "saturation": 1.4, "temperature": -0.2, "vignette": 20}
            }
        ],
        "videos": [
            {
                "id": "media-5",
                "name": "High Pacing City Drift",
                "aspect": "9:16",
                "durationSec": 15.0,
                "url": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
                "thumb": "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=200&q=80"
            }
        ]
    },
    {
        "id": "proj-3",
        "name": "Golden Hour Coast",
        "isFavorite": False,
        "createdAt": "2026-08-14T14:00:00Z",
        "updatedAt": "2026-08-14T16:10:00Z",
        "aspectRatio": "9:16",
        "targetDurationSec": 12.0,
        "soundtrack": {
            "title": "Warm Horizon",
            "tempoBpm": 105,
            "genre": "Acoustic Ambient",
            "durationSec": 12.0
        },
        "photos": [
            {
                "id": "media-2",
                "name": "Golden Hour Coastline",
                "aspect": "9:16",
                "url": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80",
                "thumb": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=200&q=80",
                "adjustments": {"brightness": 0.0, "contrast": 1.0, "exposure": 0.0, "saturation": 1.2, "temperature": 0.4, "vignette": 0}
            }
        ],
        "videos": []
    },
    {
        "id": "proj-4",
        "name": "First Project",
        "isFavorite": False,
        "createdAt": "2026-08-12T10:00:00Z",
        "updatedAt": "2026-08-12T11:20:00Z",
        "aspectRatio": "9:16",
        "targetDurationSec": 10.0,
        "soundtrack": {
            "title": "Minimal Flow",
            "tempoBpm": 90,
            "genre": "Lo-Fi",
            "durationSec": 10.0
        },
        "photos": [
            {
                "id": "media-4",
                "name": "Minimalist Architecture",
                "aspect": "9:16",
                "url": "https://images.unsplash.com/photo-1513694203232-719a280e022f?w=800&q=80",
                "thumb": "https://images.unsplash.com/photo-1513694203232-719a280e022f?w=200&q=80",
                "adjustments": {"brightness": 0.0, "contrast": 1.0, "exposure": 0.0, "saturation": 1.0, "temperature": 0.0, "vignette": 0}
            }
        ],
        "videos": []
    }
]


class UpsertProjectRequest(BaseModel):
    id: str
    name: str
    isFavorite: Optional[bool] = False
    metadata: Dict[str, Any] = {}
    photos: Optional[List[Dict[str, Any]]] = None
    videos: Optional[List[Dict[str, Any]]] = None
    soundtrack: Optional[Dict[str, Any]] = None


class AddMediaRequest(BaseModel):
    mediaType: str = Field(..., description="'photo' or 'video'")
    name: str
    url: str
    thumb: Optional[str] = None
    durationSec: Optional[float] = None
    adjustments: Optional[Dict[str, Any]] = None


async def _ensure_seed_projects(db):
    """Populates default project records if database is empty."""
    result = await db.execute(select(ProjectRecord))
    existing = result.scalars().first()
    if not existing:
        for p in DEFAULT_PROJECTS:
            record = ProjectRecord(
                id=p["id"],
                name=p["name"],
                metadata_json=json.dumps(p)
            )
            db.add(record)
        await db.commit()


@projects_router.get("")
async def list_projects():
    """Lists synchronized project metadata documents."""
    async with async_session_factory() as db:
        await _ensure_seed_projects(db)
        result = await db.execute(select(ProjectRecord).order_by(desc(ProjectRecord.updated_at)))
        records = list(result.scalars().all())
        projects = []
        for r in records:
            meta = {}
            if r.metadata_json:
                try:
                    meta = json.loads(r.metadata_json)
                except Exception:
                    meta = {}
            
            # Ensure consistent top-level fields
            proj_data = {
                "id": r.id,
                "name": r.name,
                "isFavorite": meta.get("isFavorite", False),
                "createdAt": r.created_at.isoformat() if r.created_at else meta.get("createdAt"),
                "updatedAt": r.updated_at.isoformat() if r.updated_at else meta.get("updatedAt"),
                "aspectRatio": meta.get("aspectRatio", "9:16"),
                "targetDurationSec": meta.get("targetDurationSec", 15.0),
                "soundtrack": meta.get("soundtrack", {"title": "Auto Match", "tempoBpm": 120, "genre": "Cinematic"}),
                "photos": meta.get("photos", []),
                "videos": meta.get("videos", []),
                "photoCount": len(meta.get("photos", [])),
                "videoCount": len(meta.get("videos", []))
            }
            projects.append(proj_data)
        return {"projects": projects, "totalCount": len(projects)}


@projects_router.get("/{project_id}")
async def get_project(project_id: str):
    """Fetches details for a single project including its photo and video assets."""
    async with async_session_factory() as db:
        await _ensure_seed_projects(db)
        result = await db.execute(select(ProjectRecord).where(ProjectRecord.id == project_id))
        record = result.scalar_one_or_none()
        if not record:
            raise HTTPException(status_code=404, detail="Project not found")
        
        meta = {}
        if record.metadata_json:
            try:
                meta = json.loads(record.metadata_json)
            except Exception:
                pass
        
        return {
            "id": record.id,
            "name": record.name,
            "isFavorite": meta.get("isFavorite", False),
            "createdAt": record.created_at.isoformat() if record.created_at else meta.get("createdAt"),
            "updatedAt": record.updated_at.isoformat() if record.updated_at else meta.get("updatedAt"),
            "aspectRatio": meta.get("aspectRatio", "9:16"),
            "targetDurationSec": meta.get("targetDurationSec", 15.0),
            "soundtrack": meta.get("soundtrack"),
            "photos": meta.get("photos", []),
            "videos": meta.get("videos", []),
            "photoCount": len(meta.get("photos", [])),
            "videoCount": len(meta.get("videos", []))
        }


@projects_router.post("")
async def upsert_project(request: UpsertProjectRequest):
    """Upserts project metadata record in backend persistent store."""
    async with async_session_factory() as db:
        result = await db.execute(select(ProjectRecord).where(ProjectRecord.id == request.id))
        record = result.scalar_one_or_none()

        meta = request.metadata
        if request.photos is not None:
            meta["photos"] = request.photos
        if request.videos is not None:
            meta["videos"] = request.videos
        if request.soundtrack is not None:
            meta["soundtrack"] = request.soundtrack
        meta["isFavorite"] = request.isFavorite

        if record:
            record.name = request.name
            record.metadata_json = json.dumps(meta)
        else:
            record = ProjectRecord(
                id=request.id,
                name=request.name,
                metadata_json=json.dumps(meta)
            )
            db.add(record)
        await db.commit()
        await db.refresh(record)
        return {"status": "saved", "projectId": record.id, "name": record.name}


@projects_router.post("/{project_id}/media")
async def add_project_media(project_id: str, media: AddMediaRequest):
    """Adds a new photo or video asset to an existing project document."""
    async with async_session_factory() as db:
        result = await db.execute(select(ProjectRecord).where(ProjectRecord.id == project_id))
        record = result.scalar_one_or_none()
        if not record:
            raise HTTPException(status_code=404, detail="Project not found")
        
        meta = {}
        if record.metadata_json:
            try:
                meta = json.loads(record.metadata_json)
            except Exception:
                meta = {}
        
        new_item = {
            "id": f"media-{int(datetime.utcnow().timestamp())}",
            "name": media.name,
            "url": media.url,
            "thumb": media.thumb or media.url,
            "aspect": "9:16",
            "adjustments": media.adjustments or {"brightness": 0.0, "contrast": 1.0, "exposure": 0.0, "saturation": 1.0, "temperature": 0.0, "vignette": 0}
        }
        if media.durationSec:
            new_item["durationSec"] = media.durationSec

        if media.mediaType == "video":
            videos = meta.get("videos", [])
            videos.append(new_item)
            meta["videos"] = videos
        else:
            photos = meta.get("photos", [])
            photos.append(new_item)
            meta["photos"] = photos

        record.metadata_json = json.dumps(meta)
        await db.commit()
        return {"status": "added", "media": new_item, "projectId": project_id}


@projects_router.delete("/{project_id}")
async def delete_project(project_id: str):
    """Deletes a project document from the database."""
    async with async_session_factory() as db:
        result = await db.execute(select(ProjectRecord).where(ProjectRecord.id == project_id))
        record = result.scalar_one_or_none()
        if not record:
            raise HTTPException(status_code=404, detail="Project not found")
        await db.delete(record)
        await db.commit()
        return {"status": "deleted", "projectId": project_id}
