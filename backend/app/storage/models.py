"""
SQLAlchemy ORM models for MetalCraft persistent metadata storage.
Stores projects, generation jobs, persistent artifacts, device sessions, audit events, and telemetry.
"""

from datetime import datetime
from sqlalchemy import Column, String, Integer, Float, Boolean, Text, DateTime
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class ProjectRecord(Base):
    __tablename__ = "projects"

    id = Column(String(64), primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    metadata_json = Column(Text, nullable=True)


class GenerationJobRecord(Base):
    __tablename__ = "generation_jobs"

    id = Column(String(64), primary_key=True, index=True)
    generation_id = Column(String(64), unique=True, index=True, nullable=False)
    artifact_id = Column(String(64), index=True, nullable=False)
    project_id = Column(String(64), index=True, nullable=True)
    project_name = Column(String(255), nullable=True)
    status = Column(String(32), default="PLANNING", index=True)
    progress = Column(Float, default=0.0)
    progress_message = Column(String(255), default="")
    current_frame = Column(Integer, default=0)
    total_frames = Column(Integer, default=0)
    plan_json = Column(Text, nullable=False)
    artifact_json = Column(Text, nullable=True)
    render_duration_sec = Column(Float, nullable=True)
    error = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class VideoArtifactRecord(Base):
    __tablename__ = "video_artifacts"

    id = Column(String(64), primary_key=True, index=True)
    generation_id = Column(String(64), index=True, nullable=False)
    artifact_id = Column(String(64), unique=True, index=True, nullable=False)
    project_id = Column(String(64), nullable=True)
    project_name = Column(String(255), nullable=True)
    relative_path = Column(String(512), nullable=False)
    display_name = Column(String(255), nullable=False)
    duration = Column(Float, default=0.0)
    width = Column(Integer, default=1080)
    height = Column(Integer, default=1920)
    file_size = Column(Integer, default=0)
    validation_status = Column(String(32), default="VALIDATED")
    generation_status = Column(String(32), default="COMPLETED")
    created_at = Column(DateTime, default=datetime.utcnow)


class DeviceSessionRecord(Base):
    __tablename__ = "device_sessions"

    id = Column(String(64), primary_key=True, index=True)
    session_id = Column(String(64), unique=True, index=True, nullable=False)
    device_name = Column(String(255), default="MetalCraft iOS Device")
    model = Column(String(255), default="iPhone")
    os_version = Column(String(64), default="iOS 18")
    app_version = Column(String(64), default="1.0.0")
    capabilities_json = Column(Text, nullable=True)
    status = Column(String(32), default="online", index=True)
    last_heartbeat = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)


class AuditEventRecord(Base):
    __tablename__ = "audit_events"

    id = Column(String(64), primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    category = Column(String(64), index=True)
    action = Column(String(255), nullable=False)
    status = Column(String(32), default="INFO")
    project_id = Column(String(64), nullable=True)
    project_name = Column(String(255), nullable=True)
    generation_id = Column(String(64), index=True, nullable=True)
    artifact_id = Column(String(64), nullable=True)
    media_type = Column(String(32), nullable=True)
    description = Column(Text, nullable=False)
    source = Column(String(64), default="Render Backend")


class TelemetryRecord(Base):
    __tablename__ = "telemetry_events"

    id = Column(String(64), primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    event_type = Column(String(64), index=True)
    session_id = Column(String(64), index=True)
    generation_id = Column(String(64), index=True, nullable=True)
    artifact_id = Column(String(64), nullable=True)
    operation = Column(String(255), nullable=True)
    gpu_time_ms = Column(Float, nullable=True)
    processing_time_ms = Column(Float, nullable=True)
    payload_json = Column(Text, nullable=True)
