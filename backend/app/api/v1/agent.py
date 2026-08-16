"""
Agent Planning and Gemini Creative Director API (/api/v1/agent).
"""

import uuid
from typing import Optional, Dict, Any
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.agents.director import CreativeDirector
from app.agents.schemas import EditPlan
from app.storage.database import DatabaseRepository

agent_router = APIRouter(prefix="/agent", tags=["Gemini Agent Orchestration"])
director = CreativeDirector()


class AgentCreateRequest(BaseModel):
    prompt: str
    mediaMetadata: Dict[str, Any] = {}
    thumbnailBase64: Optional[str] = None
    preferences: Optional[Dict[str, Any]] = None
    requestId: Optional[str] = None


@agent_router.post("/create")
@agent_router.post("/create-plan")
async def create_plan(request: AgentCreateRequest):
    """Executes Gemini reasoning & Parallel context research to formulate structured EditPlan."""
    req_id = request.requestId or str(uuid.uuid4())
    
    result = director.formulate_creative_plan(
        prompt=request.prompt,
        media_metadata=request.mediaMetadata,
        thumbnail_base64=request.thumbnailBase64,
        preferences=request.preferences
    )

    # Record Audit Record
    await DatabaseRepository.record_audit_event({
        "category": "ai",
        "action": "Creative Plan Formulated",
        "status": "SUCCESS",
        "generationId": result.get("editPlan", {}).get("planId"),
        "description": f"Gemini Creative Director formulated plan for prompt: '{request.prompt}'. Confidence: {result.get('confidence', 0.95):.2f}"
    })

    return {
        "requestId": req_id,
        "agentState": result.get("agentState", "Waiting for User Approval"),
        "editPlan": result.get("editPlan"),
        "reasoning": result.get("reasoning"),
        "researchContext": result.get("researchContext"),
        "confidence": result.get("confidence", 0.95),
        "estimatedProcessingTimeMs": result.get("estimatedProcessingTimeMs", 150.0)
    }


@agent_router.get("/status")
async def agent_status():
    """Returns current Gemini Creative Director readiness."""
    return {
        "status": "ready",
        "model": "gemini-2.5-flash",
        "role": "Creative Director & Lead Cinematographer",
        "capabilities": [
            "Intent Parsing",
            "Color Science & Metal Shader Mapping",
            "Multi-Scene Timeline Synthesis",
            "Parallel Research Integration",
            "Audio Mood & Soundtrack Alignment"
        ]
    }
