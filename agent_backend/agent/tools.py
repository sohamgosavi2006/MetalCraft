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

AVAILABLE_SOUNDTRACKS = [
    {
        "trackId": "cinematic_emotional_01",
        "title": "Celestial Horizons",
        "category": "Cinematic",
        "mood": "Emotional",
        "energy": "Medium",
        "duration": 45.0,
        "tags": ["cinematic", "emotional", "epic", "strings", "golden hour", "piano"]
    },
    {
        "trackId": "cinematic_dramatic_02",
        "title": "Titan Ascent",
        "category": "Cinematic",
        "mood": "Dramatic",
        "energy": "High",
        "duration": 30.0,
        "tags": ["cinematic", "dramatic", "action", "suspense", "cyberpunk", "hybrid"]
    },
    {
        "trackId": "energetic_modern_01",
        "title": "Cyber Pulse",
        "category": "Energetic",
        "mood": "Upbeat",
        "energy": "High",
        "duration": 30.0,
        "tags": ["energetic", "upbeat", "neon", "social", "reel", "electronic", "fast"]
    },
    {
        "trackId": "ambient_calm_01",
        "title": "Silent Reflections",
        "category": "Calm",
        "mood": "Relaxing",
        "energy": "Low",
        "duration": 60.0,
        "tags": ["ambient", "calm", "meditative", "peaceful", "minimal", "zen"]
    },
    {
        "trackId": "corporate_tech_01",
        "title": "Venture Flow",
        "category": "Corporate",
        "mood": "Professional",
        "energy": "Medium",
        "duration": 30.0,
        "tags": ["corporate", "technology", "presentation", "clean", "modern", "business"]
    },
    {
        "trackId": "product_luxury_01",
        "title": "Obsidian Grace",
        "category": "Product",
        "mood": "Elegant",
        "energy": "Medium",
        "duration": 30.0,
        "tags": ["product", "luxury", "commercial", "elegant", "fashion", "minimalist"]
    },
    {
        "trackId": "happy_playful_01",
        "title": "Sunny Meadows",
        "category": "Happy",
        "mood": "Uplifting",
        "energy": "High",
        "duration": 30.0,
        "tags": ["happy", "cheerful", "playful", "acoustic", "uplifting", "vlog"]
    },
    {
        "trackId": "travel_adventure_01",
        "title": "Golden Coastline",
        "category": "Travel",
        "mood": "Adventure",
        "energy": "High",
        "duration": 45.0,
        "tags": ["travel", "adventure", "summer", "nature", "scenic", "roadtrip"]
    }
]

def match_soundtrack(prompt: str, preferred_mood: Optional[str] = None) -> Dict[str, Any]:
    """Selects the best matching royalty-cleared soundtrack for a creative prompt."""
    p_lower = prompt.lower()
    
    if preferred_mood:
        for t in AVAILABLE_SOUNDTRACKS:
            if t["mood"].lower() == preferred_mood.lower():
                return t
                
    if any(w in p_lower for w in ["cyber", "action", "dramatic", "dark", "night"]):
        return AVAILABLE_SOUNDTRACKS[1] # Titan Ascent
    if any(w in p_lower for w in ["fast", "social", "reel", "upbeat", "energetic", "beat"]):
        return AVAILABLE_SOUNDTRACKS[2] # Cyber Pulse
    if any(w in p_lower for w in ["calm", "relax", "ambient", "peace", "soft"]):
        return AVAILABLE_SOUNDTRACKS[3] # Silent Reflections
    if any(w in p_lower for w in ["corporate", "tech", "business", "presentation"]):
        return AVAILABLE_SOUNDTRACKS[4] # Venture Flow
    if any(w in p_lower for w in ["luxury", "product", "commercial", "fashion", "elegant"]):
        return AVAILABLE_SOUNDTRACKS[5] # Obsidian Grace
    if any(w in p_lower for w in ["happy", "playful", "fun", "summer", "cheerful"]):
        return AVAILABLE_SOUNDTRACKS[6] # Sunny Meadows
    if any(w in p_lower for w in ["travel", "adventure", "nature", "road", "coast"]):
        return AVAILABLE_SOUNDTRACKS[7] # Golden Coastline
        
    return AVAILABLE_SOUNDTRACKS[0] # Celestial Horizons

def create_edit_plan(
    goal: str,
    reasoning: str,
    media_type: str = "image",
    adjustments: Optional[Dict[str, float]] = None,
    operations: Optional[List[Dict[str, Any]]] = None,
    scenes: Optional[List[Dict[str, Any]]] = None,
    audio_plan: Optional[Dict[str, Any]] = None,
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

    plan = {
        "schemaVersion": "1.0",
        "planId": str(uuid.uuid4()),
        "mediaType": media_type.capitalize(),
        "goal": goal,
        "reasoning": reasoning,
        "researchContext": research_context,
        "adjustments": default_adj,
        "operations": clean_ops,
        "scenes": clean_scenes,
        "audioPlan": audio_plan,
        "targetDuration": target_duration,
        "aspectRatio": aspect_ratio,
        "output": {
            "format": "jpeg" if media_type == "image" else "mp4",
            "quality": 0.95,
            "aspectRatio": aspect_ratio
        }
    }
    return plan

def validate_edit_plan(plan: Dict[str, Any]) -> Dict[str, Any]:
    """Validates an EditPlan for schema compliance, bounded parameter values, and valid operation types."""
    errors = []
    
    if plan.get("schemaVersion") != "1.0":
        errors.append("Unsupported schemaVersion")
        
    ops = plan.get("operations", [])
    valid_ops = {
        "adjustments", "grayscale", "invert", "colorInvert",
        "gaussianBlur", "boxBlur", "sharpen", "unsharpMask",
        "sobelEdge", "edgeDetection", "pixelate", "ripple",
        "swirl", "convolution", "sepia", "vignette", "filmGrain",
        "emboss", "dilation", "erosion", "posterize", "threshold",
        "channelMixer", "rgbCurve", "colorLookup", "distortion"
    }
    
    for op in ops:
        if op.get("type") not in valid_ops:
            errors.append(f"Invalid operation type: {op.get('type')}")
            
    # Validate AudioPlan if present
    audio = plan.get("audioPlan")
    if audio and isinstance(audio, dict):
        vol = audio.get("volume", 0.7)
        if not (0.0 <= vol <= 1.0):
            errors.append(f"Invalid audio volume: {vol}")
        fade_in = audio.get("fadeInDuration", 0.5)
        if not (0.0 <= fade_in <= 10.0):
            errors.append(f"Invalid fadeInDuration: {fade_in}")
        fade_out = audio.get("fadeOutDuration", 1.0)
        if not (0.0 <= fade_out <= 10.0):
            errors.append(f"Invalid fadeOutDuration: {fade_out}")
            
    return {
        "isValid": len(errors) == 0,
        "errors": errors
    }
