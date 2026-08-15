"""
Automated unit and integration tests for MetalCraft Agent Backend.
"""

import sys
import os
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import app
from agent.director import CreativeDirector
from agent.tools import validate_edit_plan

class AgentBackendTests(unittest.TestCase):
    def setUp(self):
        self.app = app.test_client()
        self.director = CreativeDirector()

    def test_health_endpoint(self):
        response = self.app.get("/health")
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data["status"], "healthy")

    def test_agent_create_golden_hour(self):
        payload = {
            "prompt": "Make this photo look cinematic with warm golden hour sunlight",
            "mediaMetadata": {
                "type": "image",
                "width": 3840,
                "height": 2160,
                "format": "jpeg"
            }
        }
        response = self.app.post("/api/v1/agent/create", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        
        self.assertIn("editPlan", data)
        plan = data["editPlan"]
        self.assertEqual(plan["schemaVersion"], "1.0")
        self.assertIn("temperature", plan["adjustments"])
        self.assertGreater(plan["adjustments"]["temperature"], 0.0)
        
        val = validate_edit_plan(plan)
        self.assertTrue(val["isValid"])

    def test_agent_create_cyberpunk_video(self):
        payload = {
            "prompt": "Give this video a cyberpunk teal and orange night aesthetic",
            "mediaMetadata": {
                "type": "video",
                "width": 1920,
                "height": 1080,
                "format": "h264",
                "fps": 60.0,
                "duration": 15.0
            }
        }
        response = self.app.post("/api/v1/agent/create", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        
        plan = data["editPlan"]
        self.assertEqual(plan["mediaType"], "Video")
        self.assertLess(plan["adjustments"]["temperature"], 0.0) # Cool cyan shadows
        
        val = validate_edit_plan(plan)
        self.assertTrue(val["isValid"])

    def test_agent_create_multi_scene_project_video(self):
        payload = {
            "prompt": "Create a 15-second cinematic product reel from this project",
            "mediaMetadata": {
                "type": "video",
                "width": 1080,
                "height": 1920,
                "format": "mp4",
                "projectName": "Product Launch 2026",
                "targetDuration": 15.0,
                "aspectRatio": "9:16",
                "assets": [
                    {"id": "asset-img-1", "name": "Hero Shot", "type": "image", "width": 1920, "height": 1080},
                    {"id": "asset-img-2", "name": "Side Angle", "type": "image", "width": 1920, "height": 1080},
                    {"id": "asset-vid-3", "name": "360 Spin", "type": "video", "width": 1920, "height": 1080, "duration": 5.0}
                ]
            }
        }
        response = self.app.post("/api/v1/agent/create", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        
        plan = data["editPlan"]
        self.assertIn("scenes", plan)
        self.assertEqual(len(plan["scenes"]), 3)
        self.assertEqual(plan["scenes"][0]["assetName"], "Hero Shot")
        self.assertEqual(plan["scenes"][2]["assetType"], "video")
        self.assertEqual(plan["aspectRatio"], "9:16")
        
        val = validate_edit_plan(plan)
        self.assertTrue(val["isValid"])

    def test_telemetry_and_observability(self):
        telemetry_event = {
            "eventType": "processing_complete",
            "sessionId": "test-session",
            "operation": "Gaussian Blur",
            "gpuTimeMs": 3.8,
            "processingTimeMs": 5.2
        }
        resp = self.app.post("/api/v1/telemetry", json=[telemetry_event])
        self.assertEqual(resp.status_code, 200)
        
        obs_resp = self.app.get("/api/v1/observability")
        self.assertEqual(obs_resp.status_code, 200)
        obs_data = obs_resp.get_json()
        self.assertGreaterEqual(obs_data["sampleCount"], 1)

    def test_agent_create_audio_plan(self):
        payload = {
            "prompt": "Create a 20-second cinematic product video with emotional background music",
            "mediaMetadata": {
                "type": "video",
                "width": 1080,
                "height": 1920,
                "format": "mp4",
                "projectName": "Watch Commercial",
                "targetDuration": 20.0,
                "assets": [
                    {"id": "img-1", "name": "Watch Dial", "type": "image"},
                    {"id": "img-2", "name": "Watch Strap", "type": "image"}
                ]
            }
        }
        response = self.app.post("/api/v1/agent/create", json=payload)
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        
        plan = data["editPlan"]
        self.assertIn("audioPlan", plan)
        audio = plan["audioPlan"]
        self.assertTrue(audio["requested"])
        self.assertIsNotNone(audio["trackId"])
        self.assertIn("volume", audio)
        self.assertGreater(audio["volume"], 0.0)
        
        val = validate_edit_plan(plan)
        self.assertTrue(val["isValid"])

if __name__ == "__main__":
    unittest.main()
