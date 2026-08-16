"""
Gemini 2.5 Flash Creative Director reasoning engine for MetalCraft Render backend.
Coordinates the closed-loop Agentic Workflow:
1. OBSERVE: Media metadata & project asset resolution
2. REASON: Understand creative intent & narrative arc
3. RESEARCH: Query Parallel for cinematography & color science
4. PLAN: Formulate structured EditPlan & AudioPlan contracts
5. VALIDATE: Ensure parameter safety, normalized ranges, and schema compliance
"""

import json
import uuid
import logging
import requests
from typing import Dict, Any, Optional, List
from datetime import datetime

from app.config import GEMINI_API_KEY
from app.agents.prompts import DIRECTOR_SYSTEM_PROMPT
from app.agents.parallel_client import research_creative_context
from app.agents.schemas import EditPlan, EditPlanScene, EditPlanAdjustments, EditPlanOperation, AudioPlan, EditPlanOutput

logger = logging.getLogger("CreativeDirector")


class CreativeDirector:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or GEMINI_API_KEY

    def formulate_creative_plan(
        self,
        prompt: str,
        media_metadata: Dict[str, Any],
        thumbnail_base64: Optional[str] = None,
        preferences: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Executes the full agentic creative direction loop."""
        # 1. OBSERVE: Extract assets & metadata
        assets = media_metadata.get("assets", [])
        media_type = media_metadata.get("type", "video" if len(assets) > 1 else "image")
        
        # 2. RESEARCH: Determine if creative research is beneficial
        research = None
        p_lower = prompt.lower()
        if any(keyword in p_lower for keyword in ["cinematic", "film", "noir", "cyberpunk", "vintage", "retro", "commercial", "luxury", "warm", "sunset"]):
            research = research_creative_context(prompt)

        # 3. REASON & PLAN: Call Gemini 2.5 Flash if API key is present
        if self.api_key:
            try:
                gemini_plan_dict = self._call_gemini_api(prompt, media_metadata, research)
                if gemini_plan_dict:
                    # Validate and parse into typed EditPlan
                    edit_plan = EditPlan(**gemini_plan_dict)
                    dumped_plan = edit_plan.model_dump(mode="json") if hasattr(edit_plan, "model_dump") else edit_plan.dict()
                    return {
                        "requestId": str(uuid.uuid4()),
                        "agentState": "Waiting for User Approval",
                        "editPlan": dumped_plan,
                        "reasoning": edit_plan.reasoning or f"Formulated by Gemini Creative Director for '{prompt}'.",
                        "researchContext": research.get("summary") if research else None,
                        "confidence": 0.95,
                        "estimatedProcessingTimeMs": 150.0
                    }
            except Exception as e:
                logger.warning(f"Gemini API call encountered error: {e}. Falling back to deterministic agent synthesis.")

        # 4. SYNTHESIZE: High-quality deterministic agent reasoning
        return self._synthesize_creative_plan(prompt, media_metadata, research)

    def _call_gemini_api(
        self,
        prompt: str,
        media_metadata: Dict[str, Any],
        research: Optional[Dict[str, Any]]
    ) -> Optional[Dict[str, Any]]:
        """Calls Google Gemini 2.5 Flash REST API."""
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={self.api_key}"
        
        system_instruction = DIRECTOR_SYSTEM_PROMPT
        user_content = f"""User Creative Intent: "{prompt}"
Media Context: {json.dumps(media_metadata)}
Research Findings: {json.dumps(research) if research else 'None'}

Generate a valid EditPlan JSON adhering to schemaVersion "1.0"."""

        payload = {
            "contents": [{"parts": [{"text": user_content}]}],
            "systemInstruction": {"parts": [{"text": system_instruction}]},
            "generationConfig": {
                "responseMimeType": "application/json",
                "temperature": 0.4
            }
        }
        
        resp = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=12.0)
        if resp.status_code == 200:
            data = resp.json()
            candidates = data.get("candidates", [])
            if candidates:
                text_content = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
                parsed = json.loads(text_content)
                if isinstance(parsed, dict) and "schemaVersion" in parsed:
                    return parsed
        else:
            logger.warning(f"Gemini API returned HTTP {resp.status_code}: {resp.text}")
        return None

    def _synthesize_creative_plan(
        self,
        prompt: str,
        media_metadata: Dict[str, Any],
        research: Optional[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Provides professional deterministic plan synthesis adhering strictly to EditPlan schema."""
        p_lower = prompt.lower()
        assets = media_metadata.get("assets", [])
        media_type = media_metadata.get("type", "video" if len(assets) > 1 else "image")
        
        adjustments = EditPlanAdjustments()
        operations: List[EditPlanOperation] = []
        scenes: List[EditPlanScene] = []
        audio_plan = None

        # Determine visual style
        if "cyberpunk" in p_lower or "neon" in p_lower:
            adjustments = EditPlanAdjustments(contrast=1.35, saturation=1.45, temperature=-0.25, tint=0.35, highlights=-0.1, shadows=0.2)
            audio_track_id = "electronic_synthwave_01"
            audio_title = "Neon Horizon Cyberpunk"
            audio_mood = "energetic"
            transition_style = "wipe"
            reasoning = "Cyberpunk styling applied: boosted cyan/magenta color contrast and vibrant neon saturation with energetic synth pacing."
        elif "golden hour" in p_lower or "warm" in p_lower or "sunset" in p_lower:
            adjustments = EditPlanAdjustments(contrast=1.1, saturation=1.2, temperature=0.45, tint=0.1, highlights=0.15, shadows=0.25)
            audio_track_id = "cinematic_emotional_01"
            audio_title = "Golden Hour Cinematic Theme"
            audio_mood = "emotional"
            transition_style = "crossfade"
            reasoning = "Golden hour warmth applied: elevated temperature, soft highlight diffusion, and slow gentle crossfades."
        elif "noir" in p_lower or "black and white" in p_lower or "monochrome" in p_lower:
            adjustments = EditPlanAdjustments(contrast=1.4, saturation=0.0, exposure=0.05, sharpness=0.2)
            operations.append(EditPlanOperation(type="grayscale", intensity=1.0))
            audio_track_id = "noir_jazz_01"
            audio_title = "Midnight Noir Solitude"
            audio_mood = "cinematic"
            transition_style = "dissolve"
            reasoning = "Film Noir aesthetic synthesized: high-contrast monochrome conversion with dramatic shadows."
        else:
            adjustments = EditPlanAdjustments(contrast=1.15, saturation=1.15, sharpness=0.15)
            audio_track_id = "corporate_tech_01"
            audio_title = "Modern Commercial Showcase"
            audio_mood = "cinematic"
            transition_style = "crossfade"
            reasoning = f"Cinematic production formulated for '{prompt}': crisp color grading, smooth transitions, and synchronized soundtrack."

        # Build scenes timeline from project assets
        if assets:
            duration_per_scene = max(2.5, min(5.0, 15.0 / len(assets)))
            zoom_effects = ["zoomIn", "panLeft", "zoomOut", "panRight"]
            for idx, asset in enumerate(assets):
                asset_id = asset.get("id", str(uuid.uuid4()))
                asset_name = asset.get("name", f"Scene {idx + 1}")
                asset_type = asset.get("type", "image")
                zoom = zoom_effects[idx % len(zoom_effects)]
                scenes.append(
                    EditPlanScene(
                        assetId=asset_id,
                        assetType=asset_type,
                        assetName=asset_name,
                        duration=duration_per_scene,
                        transition=transition_style,
                        transitionDuration=0.5,
                        zoomEffect=zoom
                    )
                )
        else:
            scenes.append(
                EditPlanScene(
                    assetId=str(uuid.uuid4()),
                    assetType="image",
                    assetName="Main Media",
                    duration=15.0 if media_type == "video" else 3.0,
                    transition=transition_style,
                    zoomEffect="zoomIn"
                )
            )

        total_duration = sum(s.duration for s in scenes)
        audio_plan = AudioPlan(
            requested=True,
            mood=audio_mood,
            style="cinematic",
            energy="medium",
            duration=total_duration,
            source="metalcraft_library",
            trackId=audio_track_id,
            trackTitle=audio_title,
            volume=0.7,
            fadeInDuration=0.5,
            fadeOutDuration=1.0
        )

        plan = EditPlan(
            schemaVersion="1.0",
            planId=f"plan_{uuid.uuid4().hex[:8]}",
            mediaType=media_type,
            goal=prompt,
            reasoning=reasoning,
            researchContext=research.get("summary") if research else None,
            adjustments=adjustments,
            operations=operations,
            scenes=scenes,
            audioPlan=audio_plan,
            targetDuration=total_duration,
            aspectRatio=media_metadata.get("aspectRatio", "9:16"),
            output=EditPlanOutput(
                format="mp4",
                quality=0.95,
                aspectRatio=media_metadata.get("aspectRatio", "9:16"),
                width=1080 if media_metadata.get("aspectRatio") != "16:9" else 1920,
                height=1920 if media_metadata.get("aspectRatio") != "16:9" else 1080
            )
        )

        dumped_plan = plan.model_dump(mode="json") if hasattr(plan, "model_dump") else plan.dict()
        return {
            "requestId": str(uuid.uuid4()),
            "agentState": "Waiting for User Approval",
            "editPlan": dumped_plan,
            "reasoning": reasoning,
            "researchContext": research.get("summary") if research else None,
            "confidence": 0.92,
            "estimatedProcessingTimeMs": 140.0
        }
