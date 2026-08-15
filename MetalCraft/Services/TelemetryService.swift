//
//  TelemetryService.swift
//  MetalCraft
//
//  Telemetry collection and event buffering service.
//  Emits granular processing, GPU timing, agent activity, and video pipeline metrics from MetalCraft
//  to power real-time in-app analytics and external Grafana observability.
//

import Foundation

// MARK: - Telemetry Event Type

enum TelemetryEventType: String, Codable, Sendable, CaseIterable {
    case processingStarted = "processing_started"
    case processingComplete = "processing_complete"
    case processingError = "processing_error"
    case frameProcessed = "frame_processed"
    case exportStarted = "export_started"
    case exportComplete = "export_complete"
    case exportFailed = "export_failed"
    case agentRequest = "agent_request"
    case agentResponse = "agent_response"
    case editPlanExecuted = "edit_plan_executed"
    
    // AI Create Video Pipeline Metrics
    case videoRenderStarted = "VIDEO_RENDER_STARTED"
    case videoRenderCompleted = "VIDEO_RENDER_COMPLETED"
    case videoArtifactCreated = "VIDEO_ARTIFACT_CREATED"
    case videoValidationStarted = "VIDEO_VALIDATION_STARTED"
    case videoValidationCompleted = "VIDEO_VALIDATION_COMPLETED"
    case videoPreviewReady = "VIDEO_PREVIEW_READY"
    case videoPreviewFailed = "VIDEO_PREVIEW_FAILED"
    case videoShared = "VIDEO_SHARED"
    case videoSavedToPhotos = "VIDEO_SAVED_TO_PHOTOS"
    case videoAddedToProject = "VIDEO_ADDED_TO_PROJECT"
}

// MARK: - Telemetry Event Model

struct TelemetryEvent: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var eventType: String
    var timestamp: Date
    var sessionId: String
    var requestId: String?
    var generationId: String?
    var artifactId: String?
    var operation: String?
    var processingTimeMs: Double?
    var gpuTimeMs: Double?
    var passCount: Int?
    var resolution: String?
    var mediaType: String?
    var errorMessage: String?
    var texturePoolSize: Int?
    var memoryUsageMB: Double?
    var status: String?
    
    init(
        id: UUID = UUID(),
        eventType: String,
        timestamp: Date = Date(),
        sessionId: String,
        requestId: String? = nil,
        generationId: String? = nil,
        artifactId: String? = nil,
        operation: String? = nil,
        processingTimeMs: Double? = nil,
        gpuTimeMs: Double? = nil,
        passCount: Int? = nil,
        resolution: String? = nil,
        mediaType: String? = nil,
        errorMessage: String? = nil,
        texturePoolSize: Int? = nil,
        memoryUsageMB: Double? = nil,
        status: String? = nil
    ) {
        self.id = id
        self.eventType = eventType
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.requestId = requestId
        self.generationId = generationId
        self.artifactId = artifactId
        self.operation = operation
        self.processingTimeMs = processingTimeMs
        self.gpuTimeMs = gpuTimeMs
        self.passCount = passCount
        self.resolution = resolution
        self.mediaType = mediaType
        self.errorMessage = errorMessage
        self.texturePoolSize = texturePoolSize
        self.memoryUsageMB = memoryUsageMB
        self.status = status
    }
}

// MARK: - Telemetry Service

@MainActor
final class TelemetryService {
    static let maxBufferSize: Int = 100
    
    let sessionId: String
    private(set) var eventsBuffer: [TelemetryEvent] = []
    
    init(sessionId: String = UUID().uuidString) {
        self.sessionId = sessionId
    }
    
    /// Records a new telemetry metric event into the rolling in-memory buffer.
    func emit(_ event: TelemetryEvent) {
        eventsBuffer.append(event)
        if eventsBuffer.count > Self.maxBufferSize {
            eventsBuffer.removeFirst(eventsBuffer.count - Self.maxBufferSize)
        }
    }
    
    /// Clears all buffered metrics in the active session.
    func clearBuffer() {
        eventsBuffer.removeAll()
    }
    
    func clear() {
        clearBuffer()
    }
    
    func emitProcessingComplete(
        operation: String,
        gpuTimeMs: Double? = nil,
        processingTimeMs: Double? = nil,
        passCount: Int? = nil,
        resolution: String? = nil,
        mediaType: String? = nil,
        requestId: String? = nil
    ) {
        emit(TelemetryEvent(
            eventType: TelemetryEventType.processingComplete.rawValue,
            sessionId: sessionId,
            requestId: requestId,
            operation: operation,
            processingTimeMs: processingTimeMs,
            gpuTimeMs: gpuTimeMs,
            passCount: passCount,
            resolution: resolution,
            mediaType: mediaType
        ))
    }
    
    func emitProcessingError(
        operation: String,
        errorMessage: String,
        mediaType: String? = nil,
        requestId: String? = nil
    ) {
        emit(TelemetryEvent(
            eventType: TelemetryEventType.processingError.rawValue,
            sessionId: sessionId,
            requestId: requestId,
            operation: operation,
            mediaType: mediaType,
            errorMessage: errorMessage
        ))
    }
    
    /// Drains all buffered events and resets the active collection buffer.
    func drainEvents() -> [TelemetryEvent] {
        let events = eventsBuffer
        eventsBuffer.removeAll()
        return events
    }
    
    func flush() -> [TelemetryEvent] {
        return drainEvents()
    }
}
