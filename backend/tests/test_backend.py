"""
Comprehensive test suite for MetalCraft Cloud Control Plane.
Verifies REST API endpoints, agent synthesis, database persistence, and device registration.
"""

import pytest
import asyncio
from httpx import AsyncClient, ASGITransport
import sys
from pathlib import Path

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_dir))

from app.main import app
from app.storage.database import init_db


import pytest_asyncio

@pytest_asyncio.fixture(autouse=True)
async def setup_db():
    await init_db()


@pytest.mark.asyncio
async def test_health_endpoint():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/v1/health")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "healthy"
        assert "providers" in data
        assert data["service"] == "MetalCraft Cloud Control Plane"


@pytest.mark.asyncio
async def test_diagnostics_test_all_endpoint():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/v1/diagnostics/test_all")
        assert resp.status_code == 200
        data = resp.json()
        assert data["overallStatus"] == "healthy"
        assert "agent" in data
        assert "gemini" in data
        assert "parallel" in data
        assert "grafana" in data
        assert "grafanaMCP" in data
        assert "telemetry" in data


@pytest.mark.asyncio
async def test_demo_info_and_stream_endpoints():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/v1/demo/info")
        assert resp.status_code == 200
        data = resp.json()
        assert "demoVideoUrl" in data
        assert "10bRFWpuJU9U3TBOJX3nyBucbd00Othp3" in data["demoVideoUrl"]
        assert data["format"] == "mp4"
        
        # Test full or range stream
        stream_resp = await client.get("/api/v1/demo/stream")
        assert stream_resp.status_code in [200, 206]
        assert stream_resp.headers.get("Accept-Ranges") == "bytes"
        assert "video/mp4" in stream_resp.headers.get("Content-Type", "")


@pytest.mark.asyncio
async def test_ios_device_registration_and_heartbeat():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        session_id = "test-device-session-123"
        reg_payload = {
            "deviceSessionId": session_id,
            "deviceName": "Soham's iPhone 11",
            "model": "iPhone 11",
            "osVersion": "iOS 18.0",
            "appVersion": "1.0.0",
            "capabilities": {
                "metal": True,
                "videoRendering": True,
                "audioMixing": True,
                "photosAccess": True,
                "maxResolution": "4K"
            }
        }
        reg_resp = await client.post("/api/v1/ios/register", json=reg_payload)
        assert reg_resp.status_code == 200
        reg_data = reg_resp.json()
        assert reg_data["status"] == "registered"
        assert reg_data["deviceSessionId"] == session_id

        # Test heartbeat
        hb_resp = await client.post("/api/v1/ios/heartbeat", json={
            "deviceSessionId": session_id,
            "status": "online"
        })
        assert hb_resp.status_code == 200
        assert hb_resp.json()["status"] == "acknowledged"

        # Test device listing
        dev_resp = await client.get("/api/v1/ios/devices")
        assert dev_resp.status_code == 200
        dev_data = dev_resp.json()
        assert dev_data["totalCount"] >= 1
        assert any(d["sessionId"] == session_id for d in dev_data["devices"])


@pytest.mark.asyncio
async def test_agent_plan_creation():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        prompt_payload = {
            "prompt": "Create a 15-second cyberpunk product reel with intense neon colors",
            "mediaMetadata": {
                "type": "video",
                "aspectRatio": "9:16",
                "assets": [
                    {"id": "media_01", "name": "Front Shot", "type": "image", "width": 1080, "height": 1920},
                    {"id": "media_02", "name": "Detail Shot", "type": "image", "width": 1080, "height": 1920}
                ]
            }
        }
        resp = await client.post("/api/v1/agent/create", json=prompt_payload)
        assert resp.status_code == 200
        data = resp.json()
        assert "editPlan" in data
        plan = data["editPlan"]
        assert plan["schemaVersion"] == "1.0"
        assert len(plan["scenes"]) == 2
        assert plan["audioPlan"] is not None
        assert data["confidence"] > 0.8


@pytest.mark.asyncio
async def test_generation_lifecycle_and_persistence():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Create a plan
        plan_resp = await client.post("/api/v1/agent/create", json={
            "prompt": "Create a warm golden hour cinematic showcase",
            "mediaMetadata": {"type": "video", "aspectRatio": "9:16"}
        })
        plan = plan_resp.json()["editPlan"]

        # 2. Dispatch generation
        gen_resp = await client.post("/api/v1/generations", json={
            "plan": plan,
            "projectName": "Test Project"
        })
        assert gen_resp.status_code == 200
        gen_data = gen_resp.json()
        gen_id = gen_data["generationId"]
        assert gen_id.startswith("gen_")

        # 3. Retrieve generation by ID
        get_resp = await client.get(f"/api/v1/generations/{gen_id}")
        assert get_resp.status_code == 200
        job_info = get_resp.json()
        assert job_info["generationId"] == gen_id
        assert job_info["projectName"] == "Test Project"

        # 4. List generations
        list_resp = await client.get("/api/v1/generations")
        assert list_resp.status_code == 200
        all_jobs = list_resp.json()["generations"]
        assert any(j["generationId"] == gen_id for j in all_jobs)


@pytest.mark.asyncio
async def test_audit_and_analytics_endpoints():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Ingest telemetry
        tel_resp = await client.post("/api/v1/telemetry", json=[
            {
                "eventType": "metal_render_progress",
                "sessionId": "session-test",
                "generationId": "gen_test_01",
                "gpuTimeMs": 2.75,
                "operation": "Sobel Edge"
            }
        ])
        assert tel_resp.status_code == 200
        assert tel_resp.json()["count"] == 1

        # Check analytics
        analytics_resp = await client.get("/api/v1/analytics")
        assert analytics_resp.status_code == 200
        adata = analytics_resp.json()
        assert "observability" in adata

        # Check audit
        audit_resp = await client.get("/api/v1/audit")
        assert audit_resp.status_code == 200
        assert "auditRecords" in audit_resp.json()
