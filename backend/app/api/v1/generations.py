"""
Generation Job Management and Lifecycle State Machine API (/api/v1/generations).
"""

import json
import uuid
from typing import Optional, Dict, Any, List
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.agents.schemas import EditPlan, GenerationJob
from app.storage.database import DatabaseRepository
from app.websocket.connection_manager import manager

generations_router = APIRouter(prefix="/generations", tags=["Generation Jobs"])


class CreateGenerationRequest(BaseModel):
    plan: EditPlan
    projectId: Optional[str] = None
    projectName: Optional[str] = None
    targetDeviceSessionId: Optional[str] = None


@generations_router.post("")
async def create_generation(request: CreateGenerationRequest):
    """Creates a new generation job, persists metadata, and dispatches the execution command to iOS."""
    gen_id = f"gen_{uuid.uuid4().hex[:8]}"
    art_id = f"artifact_video_{uuid.uuid4().hex[:8]}"

    job_data = {
        "id": gen_id,
        "generationId": gen_id,
        "artifactId": art_id,
        "projectId": request.projectId,
        "projectName": request.projectName,
        "status": "PLAN_READY",
        "progress": 0.0,
        "progressMessage": "Dispatching job to MetalCraft iOS",
        "plan": request.plan.model_dump(mode="json")
    }

    # Save to SQLite database
    record = await DatabaseRepository.save_generation_job(job_data)

    # Record Audit Record
    await DatabaseRepository.record_audit_event({
        "category": "video",
        "action": "Generation Job Created",
        "status": "INFO",
        "generationId": gen_id,
        "artifactId": art_id,
        "projectId": request.projectId,
        "projectName": request.projectName,
        "description": f"Generation job {gen_id} created with {len(request.plan.scenes)} scenes. Goal: {request.plan.goal}"
    })

    # Prepare command for iOS execution engine
    ios_command = {
        "type": "EXECUTE_GENERATION_JOB",
        "generationId": gen_id,
        "artifactId": art_id,
        "projectId": request.projectId,
        "projectName": request.projectName,
        "plan": request.plan.model_dump(mode="json")
    }

    # Send command via WebSocket or queue
    sent = await manager.send_to_ios(request.targetDeviceSessionId or "global", ios_command)
    
    # Broadcast to Web UI
    await manager.broadcast_to_web({
        "type": "GENERATION_DISPATCHED",
        "generationId": gen_id,
        "artifactId": art_id,
        "status": "EXECUTING" if sent else "WAITING_FOR_DEVICE",
        "isDispatched": sent
    })

    return {
        "generationId": gen_id,
        "artifactId": art_id,
        "status": "EXECUTING" if sent else "WAITING_FOR_DEVICE",
        "dispatchedToDevice": sent,
        "message": "Job dispatched to connected iOS device" if sent else "Job queued; waiting for MetalCraft iPhone connection."
    }


@generations_router.get("")
async def list_generations():
    """Lists all recent generation jobs from the persistent database."""
    jobs = await DatabaseRepository.list_generation_jobs(limit=50)
    result = []
    for j in jobs:
        try:
            plan_obj = json.loads(j.plan_json)
        except Exception:
            plan_obj = {}
        
        try:
            artifact_obj = json.loads(j.artifact_json) if j.artifact_json else None
        except Exception:
            artifact_obj = None

        result.append({
            "id": j.id,
            "generationId": j.generation_id,
            "artifactId": j.artifact_id,
            "projectId": j.project_id,
            "projectName": j.project_name,
            "status": j.status,
            "progress": j.progress,
            "progressMessage": j.progress_message,
            "currentFrame": j.current_frame,
            "totalFrames": j.total_frames,
            "plan": plan_obj,
            "artifact": artifact_obj,
            "renderDurationSec": j.render_duration_sec,
            "error": j.error,
            "createdAt": j.created_at.isoformat() if j.created_at else None,
            "updatedAt": j.updated_at.isoformat() if j.updated_at else None
        })
    return {"generations": result, "totalCount": len(result)}


@generations_router.get("/{generationId}")
async def get_generation(generationId: str):
    """Retrieves full status and artifact metadata for a specific generationId."""
    job = await DatabaseRepository.get_generation_job(generationId)
    if not job:
        raise HTTPException(status_code=404, detail=f"Generation job '{generationId}' not found.")

    try:
        plan_obj = json.loads(job.plan_json)
    except Exception:
        plan_obj = {}
    
    try:
        artifact_obj = json.loads(job.artifact_json) if job.artifact_json else None
    except Exception:
        artifact_obj = None

    return {
        "id": job.id,
        "generationId": job.generation_id,
        "artifactId": job.artifact_id,
        "projectId": job.project_id,
        "projectName": job.project_name,
        "status": job.status,
        "progress": job.progress,
        "progressMessage": job.progress_message,
        "currentFrame": job.current_frame,
        "totalFrames": job.total_frames,
        "plan": plan_obj,
        "artifact": artifact_obj,
        "renderDurationSec": job.render_duration_sec,
        "error": job.error,
        "createdAt": job.created_at.isoformat() if job.created_at else None,
        "updatedAt": job.updated_at.isoformat() if job.updated_at else None
    }
