"""
Asynchronous SQLite database session manager for MetalCraft Render backend.
Provides automatic table migration, connection pooling, and atomic repository operations.
"""

import json
from typing import Optional, List, Dict, Any
from datetime import datetime
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy import select, update, desc

from app.config import DATABASE_URL
from app.storage.models import (
    Base,
    ProjectRecord,
    GenerationJobRecord,
    VideoArtifactRecord,
    DeviceSessionRecord,
    AuditEventRecord,
    TelemetryRecord
)

# Async SQLite engine
engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    future=True
)

async_session_factory = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False
)


async def init_db():
    """Creates database tables if they do not already exist."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def get_db_session() -> AsyncSession:
    """FastAPI Dependency for database session injection."""
    async with async_session_factory() as session:
        try:
            yield session
        finally:
            await session.close()


# MARK: - Repository Operations

class DatabaseRepository:
    """Atomic CRUD operations for MetalCraft metadata models."""

    @staticmethod
    async def upsert_device_session(
        session_id: str,
        device_name: str,
        model: str,
        os_version: str,
        app_version: str,
        capabilities: Dict[str, Any]
    ) -> DeviceSessionRecord:
        async with async_session_factory() as db:
            result = await db.execute(select(DeviceSessionRecord).where(DeviceSessionRecord.session_id == session_id))
            record = result.scalar_one_or_none()
            if record:
                record.device_name = device_name
                record.model = model
                record.os_version = os_version
                record.app_version = app_version
                record.capabilities_json = json.dumps(capabilities)
                record.status = "online"
                record.last_heartbeat = datetime.utcnow()
            else:
                record = DeviceSessionRecord(
                    id=session_id,
                    session_id=session_id,
                    device_name=device_name,
                    model=model,
                    os_version=os_version,
                    app_version=app_version,
                    capabilities_json=json.dumps(capabilities),
                    status="online",
                    last_heartbeat=datetime.utcnow()
                )
                db.add(record)
            await db.commit()
            await db.refresh(record)
            return record

    @staticmethod
    async def update_device_heartbeat(session_id: str, status: str = "online") -> Optional[DeviceSessionRecord]:
        async with async_session_factory() as db:
            result = await db.execute(select(DeviceSessionRecord).where(DeviceSessionRecord.session_id == session_id))
            record = result.scalar_one_or_none()
            if record:
                record.status = status
                record.last_heartbeat = datetime.utcnow()
                await db.commit()
                await db.refresh(record)
            return record

    @staticmethod
    async def list_active_devices() -> List[DeviceSessionRecord]:
        async with async_session_factory() as db:
            result = await db.execute(select(DeviceSessionRecord).order_by(desc(DeviceSessionRecord.last_heartbeat)))
            return list(result.scalars().all())

    @staticmethod
    async def save_generation_job(job_data: Dict[str, Any]) -> GenerationJobRecord:
        async with async_session_factory() as db:
            gen_id = job_data.get("generationId")
            result = await db.execute(select(GenerationJobRecord).where(GenerationJobRecord.generation_id == gen_id))
            record = result.scalar_one_or_none()
            
            plan_str = json.dumps(job_data.get("plan", {}), default=str)
            artifact_str = json.dumps(job_data.get("artifact"), default=str) if job_data.get("artifact") else None

            if record:
                record.status = job_data.get("status", record.status)
                record.progress = job_data.get("progress", record.progress)
                record.progress_message = job_data.get("progressMessage", record.progress_message)
                record.current_frame = job_data.get("currentFrame", record.current_frame)
                record.total_frames = job_data.get("totalFrames", record.total_frames)
                record.render_duration_sec = job_data.get("renderDurationSec", record.render_duration_sec)
                record.error = job_data.get("error", record.error)
                if artifact_str:
                    record.artifact_json = artifact_str
            else:
                record = GenerationJobRecord(
                    id=job_data.get("id", gen_id),
                    generation_id=gen_id,
                    artifact_id=job_data.get("artifactId", f"artifact_{gen_id}"),
                    project_id=job_data.get("projectId"),
                    project_name=job_data.get("projectName"),
                    status=job_data.get("status", "PLANNING"),
                    progress=job_data.get("progress", 0.0),
                    progress_message=job_data.get("progressMessage", ""),
                    current_frame=job_data.get("currentFrame", 0),
                    total_frames=job_data.get("totalFrames", 0),
                    plan_json=plan_str,
                    artifact_json=artifact_str,
                    render_duration_sec=job_data.get("renderDurationSec"),
                    error=job_data.get("error")
                )
                db.add(record)
            
            await db.commit()
            await db.refresh(record)
            return record

    @staticmethod
    async def get_generation_job(generation_id: str) -> Optional[GenerationJobRecord]:
        async with async_session_factory() as db:
            result = await db.execute(select(GenerationJobRecord).where(GenerationJobRecord.generation_id == generation_id))
            return result.scalar_one_or_none()

    @staticmethod
    async def list_generation_jobs(limit: int = 50) -> List[GenerationJobRecord]:
        async with async_session_factory() as db:
            result = await db.execute(
                select(GenerationJobRecord)
                .order_by(desc(GenerationJobRecord.created_at))
                .limit(limit)
            )
            return list(result.scalars().all())

    @staticmethod
    async def save_video_artifact(artifact_data: Dict[str, Any]) -> VideoArtifactRecord:
        async with async_session_factory() as db:
            art_id = artifact_data.get("artifactId")
            result = await db.execute(select(VideoArtifactRecord).where(VideoArtifactRecord.artifact_id == art_id))
            record = result.scalar_one_or_none()
            if not record:
                record = VideoArtifactRecord(
                    id=artifact_data.get("id", art_id),
                    generation_id=artifact_data.get("generationId"),
                    artifact_id=art_id,
                    project_id=artifact_data.get("projectId"),
                    project_name=artifact_data.get("projectName"),
                    relative_path=artifact_data.get("relativePath", f"Artifacts/{art_id}.mp4"),
                    display_name=artifact_data.get("displayName", "MetalCraft Video Reel"),
                    duration=artifact_data.get("duration", 0.0),
                    width=artifact_data.get("width", 1080),
                    height=artifact_data.get("height", 1920),
                    file_size=artifact_data.get("fileSize", 0),
                    validation_status=artifact_data.get("validationStatus", "VALIDATED"),
                    generation_status=artifact_data.get("generationStatus", "COMPLETED")
                )
                db.add(record)
                await db.commit()
                await db.refresh(record)
            return record

    @staticmethod
    async def record_audit_event(event_data: Dict[str, Any]) -> AuditEventRecord:
        async with async_session_factory() as db:
            record = AuditEventRecord(
                id=event_data.get("id", f"audit_{datetime.utcnow().timestamp()}"),
                category=event_data.get("category", "system"),
                action=event_data.get("action", "General Event"),
                status=event_data.get("status", "INFO"),
                project_id=event_data.get("projectId"),
                project_name=event_data.get("projectName"),
                generation_id=event_data.get("generationId"),
                artifact_id=event_data.get("artifactId"),
                media_type=event_data.get("mediaType"),
                description=event_data.get("description", ""),
                source=event_data.get("source", "Render Backend")
            )
            db.add(record)
            await db.commit()
            await db.refresh(record)
            return record

    @staticmethod
    async def list_audit_events(limit: int = 100, category: Optional[str] = None) -> List[AuditEventRecord]:
        async with async_session_factory() as db:
            query = select(AuditEventRecord).order_by(desc(AuditEventRecord.timestamp)).limit(limit)
            if category and category.lower() != "all":
                query = query.where(AuditEventRecord.category == category)
            result = await db.execute(query)
            return list(result.scalars().all())

    @staticmethod
    async def record_telemetry(event_data: Dict[str, Any]) -> TelemetryRecord:
        async with async_session_factory() as db:
            record = TelemetryRecord(
                id=event_data.get("id", f"tel_{datetime.utcnow().timestamp()}"),
                event_type=event_data.get("eventType", "unknown"),
                session_id=event_data.get("sessionId", "global"),
                generation_id=event_data.get("generationId"),
                artifact_id=event_data.get("artifactId"),
                operation=event_data.get("operation"),
                gpu_time_ms=event_data.get("gpuTimeMs"),
                processing_time_ms=event_data.get("processingTimeMs"),
                payload_json=json.dumps(event_data)
            )
            db.add(record)
            await db.commit()
            await db.refresh(record)
            return record

    @staticmethod
    async def list_telemetry_events(limit: int = 100) -> List[TelemetryRecord]:
        async with async_session_factory() as db:
            result = await db.execute(
                select(TelemetryRecord)
                .order_by(desc(TelemetryRecord.timestamp))
                .limit(limit)
            )
            return list(result.scalars().all())
