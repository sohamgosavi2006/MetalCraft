"""
Strongly typed Pydantic contracts and DTO schemas for MetalCraft.
Ensures uniform serialization across Web UI, Gemini Creative Director, Parallel, and iOS client.
"""

from typing import List, Optional, Dict, Any, Union
from datetime import datetime
import uuid
from pydantic import BaseModel, Field


# MARK: - Adjustments Contract

class EditPlanAdjustments(BaseModel):
    exposure: float = 0.0
    contrast: float = 1.0
    saturation: float = 1.0
    highlights: float = 0.0
    shadows: float = 0.0
    temperature: float = 0.0
    tint: float = 0.0
    sharpness: float = 0.0


# MARK: - Operations Contract

class EditPlanOperation(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    type: str  # "grayscale", "invert", "gaussian_blur", "sobel", "pixelate", "ripple", "swirl"
    intensity: float = 1.0
    radius: Optional[float] = None
    sigma: Optional[float] = None
    scale: Optional[float] = None
    frequency: Optional[float] = None
    angle: Optional[float] = None
    center_x: Optional[float] = 0.5
    center_y: Optional[float] = 0.5


# MARK: - Scene Contract (Multi-Scene Timeline)

class EditPlanScene(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    assetId: Optional[str] = None  # Stable mediaId
    assetType: str = "image"  # "image" or "video"
    assetName: str = "Scene Asset"
    duration: float = 3.0
    startTime: float = 0.0
    transition: Optional[str] = "crossfade"  # "crossfade", "fadeBlack", "wipe", "dissolve", "none"
    transitionDuration: Optional[float] = 0.5
    adjustments: Optional[EditPlanAdjustments] = None
    operations: Optional[List[EditPlanOperation]] = None
    zoomEffect: Optional[str] = "zoomIn"  # "zoomIn", "zoomOut", "panLeft", "panRight", "none"


# MARK: - AudioPlan Contract

class AudioPlan(BaseModel):
    requested: bool = False
    mood: Optional[str] = "cinematic"
    style: Optional[str] = "cinematic"
    energy: Optional[str] = "medium"
    duration: Optional[float] = None
    source: str = "metalcraft_library"  # "metalcraft_library", "project_music", "imported", "none"
    trackId: Optional[str] = "cinematic_emotional_01"
    trackTitle: Optional[str] = "Cinematic Emotional Theme"
    volume: float = 0.7
    fadeInDuration: float = 0.5
    fadeOutDuration: float = 1.0
    duckingFactor: float = 0.3


# MARK: - Output Specification

class EditPlanOutput(BaseModel):
    format: str = "mp4"
    quality: float = 0.95
    aspectRatio: Optional[str] = "9:16"
    width: int = 1080
    height: int = 1920


# MARK: - Root EditPlan Contract

class EditPlan(BaseModel):
    schemaVersion: str = "1.0"
    planId: str = Field(default_factory=lambda: str(uuid.uuid4()))
    createdAt: datetime = Field(default_factory=datetime.utcnow)
    mediaType: str = "video"  # "image" or "video"
    goal: str = "Cinematic Media Production"
    reasoning: str = ""
    researchContext: Optional[str] = None
    adjustments: EditPlanAdjustments = Field(default_factory=EditPlanAdjustments)
    operations: List[EditPlanOperation] = Field(default_factory=list)
    scenes: List[EditPlanScene] = Field(default_factory=list)
    audioPlan: Optional[AudioPlan] = None
    targetDuration: Optional[float] = None
    aspectRatio: Optional[str] = "9:16"
    output: EditPlanOutput = Field(default_factory=EditPlanOutput)


# MARK: - Video Artifact Contract

class VideoArtifact(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    generationId: str
    artifactId: str
    projectId: Optional[str] = None
    projectName: Optional[str] = None
    relativePath: str
    displayName: str
    duration: float
    width: int = 1080
    height: int = 1920
    fileSize: int = 0
    formattedFileSize: str = ""
    createdAt: datetime = Field(default_factory=datetime.utcnow)
    validationStatus: str = "VALIDATED"
    generationStatus: str = "COMPLETED"


# MARK: - Generation Job Contract

class GenerationJobStatus(str):
    PLANNING = "PLANNING"
    PREPARING = "PREPARING"
    PROCESSING = "PROCESSING"
    RENDERING = "RENDERING"
    EXPORTING = "EXPORTING"
    VALIDATING = "VALIDATING"
    ARTIFACT_CREATED = "ARTIFACT_CREATED"
    PREVIEW_READY = "PREVIEW_READY"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"


class GenerationJob(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    generationId: str = Field(default_factory=lambda: f"gen_{uuid.uuid4().hex[:8]}")
    artifactId: str = Field(default_factory=lambda: f"artifact_video_{uuid.uuid4().hex[:8]}")
    projectId: Optional[str] = None
    projectName: Optional[str] = None
    status: str = "PLANNING"
    createdAt: datetime = Field(default_factory=datetime.utcnow)
    updatedAt: datetime = Field(default_factory=datetime.utcnow)
    plan: EditPlan
    progress: float = 0.0
    progressMessage: str = "Review proposed creative plan"
    currentFrame: int = 0
    totalFrames: int = 0
    artifact: Optional[VideoArtifact] = None
    outputURL: Optional[str] = None
    outputFileSizeFormatted: Optional[str] = None
    renderDurationSec: Optional[float] = None
    error: Optional[str] = None


# MARK: - Device Session & Registration

class DeviceCapabilities(BaseModel):
    metal: bool = True
    metalMaxThreadsPerGroup: int = 1024
    videoRendering: bool = True
    audioMixing: bool = True
    photosAccess: bool = True
    maxResolution: str = "4K"


class DeviceRegistrationRequest(BaseModel):
    deviceSessionId: str = Field(default_factory=lambda: str(uuid.uuid4()))
    deviceName: str = "Soham's iPhone"
    model: str = "iPhone 11 (A13 Bionic)"
    osVersion: str = "iOS 18.0"
    appVersion: str = "1.0.0"
    capabilities: DeviceCapabilities = Field(default_factory=DeviceCapabilities)


class DeviceHeartbeatRequest(BaseModel):
    deviceSessionId: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    status: str = "online"
    activeJobId: Optional[str] = None


# MARK: - Audit Event Model

class AuditEvent(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    category: str  # "project", "media", "ai", "video", "audio", "system", "errors"
    action: str
    status: str  # "SUCCESS", "WARNING", "FAILURE", "INFO"
    projectId: Optional[str] = None
    projectName: Optional[str] = None
    generationId: Optional[str] = None
    artifactId: Optional[str] = None
    mediaType: Optional[str] = None
    description: str
    source: str = "Render Backend"
