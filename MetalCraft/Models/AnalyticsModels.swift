//
//  AnalyticsModels.swift
//  MetalCraft
//
//  Live runtime status, node execution states, memory estimates,
//  and session history models for the Metal Craft Analytics dashboard.
//

import Foundation
import Metal

// MARK: - Live System Operation Status

enum OperationStatus: String, Codable, Sendable, Equatable {
    case idle = "Idle"
    case processing = "Processing"
    case rendering = "Rendering"
    case exporting = "Exporting"
    case benchmarking = "Benchmarking"
    case loading = "Loading"
    case completed = "Completed"
    case failed = "Failed"
    
    var colorName: String {
        switch self {
        case .idle: return "gray"
        case .processing, .rendering, .exporting, .benchmarking, .loading: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        }
    }
}

// MARK: - Pipeline Node Runtime State

enum NodeRuntimeState: String, Codable, Sendable, Equatable {
    case waiting = "Waiting"
    case queued = "Queued"
    case running = "Running"
    case completed = "Completed"
    case skipped = "Disabled"
    case failed = "Failed"
    
    var iconName: String {
        switch self {
        case .waiting: return "circle"
        case .queued: return "clock"
        case .running: return "record.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "slash.circle"
        case .failed: return "xmark.circle.fill"
        }
    }
}

// MARK: - Processing History Entry

struct ProcessingHistoryEntry: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let operationName: String
    let gpuTimeMs: Double
    let frameTimeMs: Double
    let passCount: Int
    let resolutionText: String
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operationName: String,
        gpuTimeMs: Double,
        frameTimeMs: Double,
        passCount: Int,
        resolutionText: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operationName = operationName
        self.gpuTimeMs = gpuTimeMs
        self.frameTimeMs = frameTimeMs
        self.passCount = passCount
        self.resolutionText = resolutionText
    }
}

// MARK: - Export History Entry

struct ExportHistoryEntry: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let format: String
    let resolution: String
    let fileSizeFormatted: String
    let destination: String
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        format: String,
        resolution: String,
        fileSizeFormatted: String,
        destination: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.format = format
        self.resolution = resolution
        self.fileSizeFormatted = fileSizeFormatted
        self.destination = destination
    }
}

// MARK: - Memory & Resource Metrics

struct MemoryResourceMetrics: Sendable, Equatable {
    var originalTextureBytesEstimated: Int = 0
    var intermediateTexturesBytesEstimated: Int = 0
    var activePooledTextures: Int = 0
    var reusablePooledTextures: Int = 0
    var memoryPressureState: String = "Normal"
    
    var originalTextureMBFormatted: String {
        let mb = Double(originalTextureBytesEstimated) / (1024.0 * 1024.0)
        return String(format: "~%.1f MB", mb)
    }
    
    var intermediateTexturesMBFormatted: String {
        let mb = Double(intermediateTexturesBytesEstimated) / (1024.0 * 1024.0)
        return String(format: "~%.1f MB", mb)
    }
    
    var totalEstimatedWorkingSetMBFormatted: String {
        let totalBytes = originalTextureBytesEstimated + intermediateTexturesBytesEstimated
        let mb = Double(totalBytes) / (1024.0 * 1024.0)
        return String(format: "~%.1f MB", mb)
    }
}
