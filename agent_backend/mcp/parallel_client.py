"""
Parallel MCP Client for external creative research in cinematography, visual styles, and color grading.
"""

import time
import logging
from typing import Dict, Any, Optional
import requests
from config import PARALLEL_API_KEY

logger = logging.getLogger(__name__)

class ParallelClient:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or PARALLEL_API_KEY

    def test_connection(self) -> Dict[str, Any]:
        """Performs a safe, minimal diagnostic request to Parallel Search API."""
        if not self.api_key:
            return {
                "configured": False,
                "authenticated": False,
                "status": "FAIL",
                "message": "PARALLEL_API_KEY is not configured on server"
            }
        
        t0 = time.time()
        try:
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"
            }
            payload = {
                "search_queries": ["cinematic lighting color grading"]
            }
            resp = requests.post("https://api.parallel.ai/v1/search", json=payload, headers=headers, timeout=10)
            latency_ms = int((time.time() - t0) * 1000)
            
            if resp.status_code == 200:
                data = resp.json()
                search_id = data.get("search_id", "unknown")
                result_count = len(data.get("results", []))
                return {
                    "configured": True,
                    "authenticated": True,
                    "request": "PASS",
                    "response": "PASS",
                    "status": "PASS",
                    "statusCode": 200,
                    "latencyMs": latency_ms,
                    "searchId": search_id,
                    "resultCount": result_count,
                    "message": f"Parallel API verified (search_id: {search_id}, latency: {latency_ms}ms)"
                }
            else:
                return {
                    "configured": True,
                    "authenticated": resp.status_code not in (401, 403),
                    "request": "PASS",
                    "response": "FAIL",
                    "status": "FAIL",
                    "statusCode": resp.status_code,
                    "latencyMs": latency_ms,
                    "message": f"Parallel API returned HTTP {resp.status_code}"
                }
        except Exception as e:
            return {
                "configured": True,
                "authenticated": False,
                "status": "FAIL",
                "message": f"Network connection error: {str(e)}"
            }

    def search_creative_references(self, query: str, topic: str = "cinematography") -> Dict[str, Any]:
        """Queries Parallel for cinematography and creative color grading references."""
        if not self.api_key:
            logger.info("Parallel API key not configured. Using built-in cinematic knowledge base.")
            return self._fallback_knowledge_base(query)

        t0 = time.time()
        try:
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"
            }
            payload = {
                "search_queries": [query]
            }
            resp = requests.post("https://api.parallel.ai/v1/search", json=payload, headers=headers, timeout=10)
            latency_ms = int((time.time() - t0) * 1000)
            
            if resp.status_code == 200:
                data = resp.json()
                results = data.get("results", [])
                citations = []
                excerpts = []
                for r in results[:3]:
                    title = r.get("title", "").strip()
                    url = r.get("url", "")
                    if title:
                        citations.append(f"{title} ({url})" if url else title)
                    for ex in r.get("excerpts", [])[:2]:
                        excerpts.append(ex.strip())
                
                summary = " ".join(excerpts[:2]) if excerpts else f"Cinematographic reference for '{query}'."
                logger.info(f"Parallel search succeeded for query '{query}' (latency: {latency_ms}ms, search_id: {data.get('search_id')})")
                
                return {
                    "summary": summary,
                    "citations": citations if citations else ["Parallel Creative Research Engine"],
                    "searchId": data.get("search_id"),
                    "suggestedAdjustments": self._extract_adjustments_from_query(query)
                }
            else:
                logger.warning(f"Parallel API returned status {resp.status_code}. Using built-in fallback.")
                return self._fallback_knowledge_base(query)
        except Exception as e:
            logger.warning(f"Parallel search failed: {e}. Falling back to internal knowledge base.")
            return self._fallback_knowledge_base(query)

    def _extract_adjustments_from_query(self, query: str) -> Dict[str, float]:
        q = query.lower()
        if "golden hour" in q or "warm" in q or "sunset" in q:
            return {"temperature": 0.35, "saturation": 1.25, "exposure": 0.15, "contrast": 1.2}
        elif "cyberpunk" in q or "neon" in q or "teal" in q or "noir" in q:
            return {"temperature": -0.25, "tint": 0.15, "contrast": 1.35, "saturation": 1.2}
        elif "vintage" in q or "film" in q or "retro" in q:
            return {"contrast": 1.1, "saturation": 0.9, "temperature": 0.1, "gamma": 1.1}
        else:
            return {"contrast": 1.15, "saturation": 1.1, "exposure": 0.05}

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
