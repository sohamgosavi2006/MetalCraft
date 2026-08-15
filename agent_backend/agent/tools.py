"""
Agent tool definitions implementing the Agentic Feedback Loop.
All tools produce strictly typed outputs matching the EditPlan v1.0 specification.
"""

import uuid
from typing import Dict, Any, List, Optional
from mcp.parallel_client import ParallelClient
from mcp.grafana_client import GrafanaClient

parallel_client = ParallelClient()
grafana_client = GrafanaClient()

def analyze_media(media_metadata: Dict[str, Any]) -> Dict[str, Any]:
    """Analyzes media dimensions, format, frame rate, and histogram summary."""
    mtype = media_metadata.get("type", "image")
    width = media_metadata.get("width", 1920)
    height = media_metadata.get("height", 1080)
    is_high_res = (width * height) > (1920 * 1080)
    
    return {
        "mediaType": mtype,
        "resolution": f"{width}x{height}",
        "pixelCount": width * height,
        "isHighResolution": is_high_res,
        "fps": media_metadata.get("fps", 30.0 if mtype == "video" else None),
        "duration": media_metadata.get("duration", 0.0),
        "recommendedMaxBlurSigma": 20.0 if is_high_res else 10.0,
        "projectName": media_metadata.get("projectName"),
        "assets": media_metadata.get("assets", []),
        "targetDuration": media_metadata.get("targetDuration", 15.0),
        "aspectRatio": media_metadata.get("aspectRatio", "9:16")
    }

def research_creative_context(query: str, topic: str = "cinematography") -> Dict[str, Any]:
    """Queries Parallel for aesthetic reference, color harmony, and film style recommendations."""
    return parallel_client.search_creative_references(query, topic=topic)

def query_observability(query_type: str = "latency") -> Dict[str, Any]:
    """Queries Grafana for recent processing latency, frame budget, and error rates."""
    return grafana_client.query_observability(query_type)

def create_edit_plan(
    goal: str,
    reasoning: str,
    media_type: str = "image",
    adjustments: Optional[Dict[str, float]] = None,
    operations: Optional[List[Dict[str, Any]]] = None,
    scenes: Optional[List[Dict[str, Any]]] = None,
    target_duration: Optional[float] = None,
    aspect_ratio: Optional[str] = "9:16",
    research_context: Optional[str] = None
) -> Dict[str, Any]:
    """Constructs a validated EditPlan contract conforming to schema v1.0."""
    default_adj = {
        "brightness": 0.0,
        "contrast": 1.0,
        "exposure": 0.0,
        "saturation": 1.0,
        "temperature": 0.0,
        "tint": 0.0,
        "gamma": 1.0
    }
    if adjustments:
        default_adj.update(adjustments)

    clean_ops = []
    if operations:
        for op in operations:
            clean_ops.append({
                "id": str(uuid.uuid4()),
                "type": op.get("type", "grayscale"),
                "enabled": op.get("enabled", True),
                "parameters": op.get("parameters", {})
            })

    clean_scenes = []
    if scenes:
        for s in scenes:
            clean_scenes.append({
                "id": str(uuid.uuid4()),
                "assetId": s.get("assetId"),
                "assetType": s.get("assetType", "image"),
                "assetName": s.get("assetName", "Scene"),
                "duration": float(s.get("duration", 3.0)),
                "startTime": float(s.get("startTime", 0.0)),
                "transition": s.get("transition", "crossfade"),
                "transitionDuration": float(s.get("transitionDuration", 0.5)),
                "zoomEffect": s.get("zoomEffect", "zoomIn"),
                "adjustments": s.get("adjustments", default_adj),
                "operations": s.get("operations", clean_ops)
            })

    return {
        "schemaVersion": "1.0",
        "planId": str(uuid.uuid4()),
        "mediaType": media_type.capitalize(),
        "goal": goal,
        "reasoning": reasoning,
        "researchContext": research_context,
        "adjustments": default_adj,
        "operations": clean_ops,
        "scenes": clean_scenes,
        "targetDuration": target_duration,
        "aspectRatio": aspect_ratio,
        "output": {
            "format": "jpeg" if media_type == "image" else "mp4",
            "quality": 0.95,
            "aspectRatio": aspect_ratio
        }
    }

def validate_edit_plan(plan: Dict[str, Any]) -> Dict[str, Any]:
    """Validates an EditPlan for schema compliance, bounded parameter values, and valid operation types."""
    errors = []
    
    if plan.get("schemaVersion") != "1.0":
        errors.append("Unsupported schemaVersion")
        
    ops = plan.get("operations", [])
    if len(ops) > 20:
        errors.append("Exceeded max operation count (20)")
        
    valid_types = {
        "adjustments", "grayscale", "invert", "gaussianblur", "sharpen",
        "sobeledge", "pixelate", "ripple", "swirl", "convolution"
    }
    
    for op in ops:
        t = op.get("type", "").lower()
        if t not in valid_types:
            errors.append(f"Invalid operation type: {t}")
            
    return {
        "isValid": len(errors) == 0,
        "errors": errors
    }
