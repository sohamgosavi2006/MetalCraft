"""
Parallel MCP Client for external creative research in cinematography, visual styles, and color grading.
"""

import logging
from typing import Dict, Any, Optional
import requests
from config import PARALLEL_API_KEY

logger = logging.getLogger(__name__)

class ParallelClient:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or PARALLEL_API_KEY

    def search_creative_references(self, query: str, topic: str = "cinematography") -> Dict[str, Any]:
        """Queries Parallel for cinematography and creative color grading references."""
        if not self.api_key:
            logger.info("Parallel API key not configured. Using built-in cinematic knowledge base.")
            return self._fallback_knowledge_base(query)

        try:
            # Parallel MCP / API endpoint
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"
            }
            payload = {
                "query": query,
                "topic": topic,
                "max_results": 3
            }
            resp = requests.post("https://api.parallel.ai/v1/search", json=payload, headers=headers, timeout=5)
            if resp.status_code == 200:
                return resp.json()
            else:
                logger.warning(f"Parallel API returned status {resp.status_code}")
                return self._fallback_knowledge_base(query)
        except Exception as e:
            logger.warning(f"Parallel search failed: {e}. Falling back to internal knowledge base.")
            return self._fallback_knowledge_base(query)

    def _fallback_knowledge_base(self, query: str) -> Dict[str, Any]:
        q = query.lower()
        if "golden hour" in q or "warm" in q or "sunset" in q:
            return {
                "summary": "Golden hour cinematography utilizes warm color balance (+0.2 to +0.4 temperature), softened highlights with mild diffusion, and rich contrast (1.2-1.3) to evoke natural sunlight.",
                "citations": ["American Cinematographer: Natural Light in Modern Cinema", "ASC Color Grading Guidelines"],
                "suggestedAdjustments": {"temperature": 0.35, "saturation": 1.25, "exposure": 0.15, "contrast": 1.2}
            }
        elif "cyberpunk" in q or "neon" in q or "teal" in q or "noir" in q:
            return {
                "summary": "Cyberpunk & Neo-Noir visual aesthetics rely on complementary split-toning (cool shadows via -0.3 temperature, cyan-magenta tint shifts) with sharp micro-contrast (1.35) and deep blacks.",
                "citations": ["Blade Runner 2049 Visual Study", "Digital Intermediates & LUT Design"],
                "suggestedAdjustments": {"temperature": -0.25, "tint": 0.15, "contrast": 1.35, "saturation": 1.2}
            }
        elif "vintage" in q or "film" in q or "retro" in q:
            return {
                "summary": "Vintage film emulation utilizes gentle contrast curves, slight warmth, and subtle softness with mild gamma lift.",
                "citations": ["Kodak Vision3 500T Characteristic Curves"],
                "suggestedAdjustments": {"contrast": 1.1, "saturation": 0.9, "temperature": 0.1, "gamma": 1.1}
            }
        else:
            return {
                "summary": "Commercial grading focuses on clean, neutral color rendering, high clarity, vibrant subject saturation, and balanced exposure.",
                "citations": ["Commercial Filmmaking Standard Practices"],
                "suggestedAdjustments": {"contrast": 1.15, "saturation": 1.1, "exposure": 0.05}
            }
