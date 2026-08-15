//
//  TelemetryService.swift
//  MetalCraft
//
//  Telemetry collection and event buffering service.
//  Emits granular processing, GPU timing, and agent activity metrics from MetalCraft
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
}

// MARK: - Telemetry Event Model

struct TelemetryEvent: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var eventType: String
    var timestamp: Date
    var sessionId: String
    var requestId: String?
    var operation: String?
    var processingTimeMs: Double?
    var gpuTimeMs: Double?
    var passCount: Int?
    var resolution: String?
    var mediaType: String?
    var errorMessage: String?
    var texturePoolSize: Int?
    var memoryUsageMB: Double?
    
    init(
        id: UUID = UUID(),
        eventType: String,
        timestamp: Date = Date(),
        sessionId: String,
        requestId: String? = nil,
        operation: String? = nil,
        processingTimeMs: Double? = nil,
        gpuTimeMs: Double? = nil,
        passCount: Int? = nil,
        resolution: String? = nil,
        mediaType: String? = nil,
        errorMessage: String? = nil,
        texturePoolSize: Int? = nil,
        memoryUsageMB: Double? = nil
    ) {
        self.id = id
        self.eventType = eventType
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.requestId = requestId
        self.operation = operation
        self.processingTimeMs = processingTimeMs
        self.gpuTimeMs = gpuTimeMs
        self.passCount = passCount
        self.resolution = resolution
        self.mediaType = mediaType
        self.errorMessage = errorMessage
        self.texturePoolSize = texturePoolSize
        self.memoryUsageMB = memoryUsageMB
    }
}

// MARK: - Telemetry Service

@MainActor
final class TelemetryService {
    static let maxBufferSize: Int = 100
    
    let sessionId: String
    private(set) var eventsBuffer: [TelemetryEvent] = []
    
    var onEventEmitted: ((TelemetryEvent) -> Void)?
    
    init(sessionId: String = UUID().uuidString) {
        self.sessionId = sessionId
    }
    
    /// Emits a structured telemetry event and adds it to the local circular buffer.
    func emit(_ event: TelemetryEvent) {
        eventsBuffer.append(event)
        
        // Evict oldest events if buffer exceeds max capacity
        if eventsBuffer.count > Self.maxBufferSize {
            eventsBuffer.removeFirst(eventsBuffer.count - Self.maxBufferSize)
        }
        
        onEventEmitted?(event)
    }
    
    /// Convenience method to emit a processing completion event.
    func emitProcessingComplete(
        operation: String,
        gpuTimeMs: Double,
        processingTimeMs: Double,
        passCount: Int,
        resolution: String,
        mediaType: String = "image",
        requestId: String? = nil
    ) {
        let event = TelemetryEvent(
            eventType: TelemetryEventType.processingComplete.rawValue,
            sessionId: sessionId,
            requestId: requestId,
            operation: operation,
            processingTimeMs: processingTimeMs,
            gpuTimeMs: gpuTimeMs,
            passCount: passCount,
            resolution: resolution,
            mediaType: mediaType
        )
        emit(event)
    }
    
    /// Convenience method to emit a processing error event.
    func emitProcessingError(
        operation: String,
        errorMessage: String,
        mediaType: String = "image",
        requestId: String? = nil
    ) {
        let event = TelemetryEvent(
            eventType: TelemetryEventType.processingError.rawValue,
            sessionId: sessionId,
            requestId: requestId,
            operation: operation,
            mediaType: mediaType,
            errorMessage: errorMessage
        )
        emit(event)
    }
    
    /// Flushes and returns the buffered telemetry events, clearing the local buffer.
    func flush() -> [TelemetryEvent] {
        let batch = eventsBuffer
        eventsBuffer.removeAll()
        return batch
    }
    
    /// Clears all buffered events without returning.
    func clear() {
        eventsBuffer.removeAll()
    }
}
