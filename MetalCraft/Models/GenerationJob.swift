//
//  GenerationJob.swift
//  MetalCraft
//
//  Represents an idempotent, stateful AI Video Generation Job.
//  Separates chat conversation messages from visual media generation artifacts,
//  providing a stable lifecycle (Planning -> Preparing -> Rendering -> Exporting -> Validating -> Completed)
//  keyed by unique generationId and artifactId to prevent duplicate cards upon follow-up prompts.
//

import Foundation
import UIKit

enum GenerationJobStatus: String, Codable, Sendable, CaseIterable {
    case planning = "PLANNING"
    case preparing = "PREPARING"
    case processing = "PROCESSING"
    case rendering = "RENDERING"
    case exporting = "EXPORTING"
    case validating = "VALIDATING"
    case completed = "COMPLETED"
    case failed = "FAILED"
    
    var displayName: String {
        switch self {
        case .planning: return "Plan Proposed"
        case .preparing: return "Preparing Media"
        case .processing: return "Processing Assets"
        case .rendering: return "Rendering on Metal GPU"
        case .exporting: return "Mixing Audio & Exporting"
        case .validating: return "Validating Output"
        case .completed: return "Production Ready"
        case .failed: return "Generation Failed"
        }
    }
    
    var iconName: String {
        switch self {
        case .planning: return "wand.and.stars"
        case .preparing: return "photo.stack"
        case .processing: return "cpu"
        case .rendering: return "bolt.fill"
        case .exporting: return "music.note"
        case .validating: return "checkmark.shield.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}

struct GenerationJob: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let generationId: String
    let artifactId: String
    var projectId: UUID?
    var projectName: String?
    var status: GenerationJobStatus
    var createdAt: Date
    var updatedAt: Date
    var plan: EditPlan
    var progress: Double
    var progressMessage: String
    var currentFrame: Int
    var totalFrames: Int
    var outputURL: URL?
    var outputFileSizeFormatted: String?
    var renderDurationSec: Double?
    var error: String?
    
    init(
        id: UUID = UUID(),
        generationId: String? = nil,
        artifactId: String? = nil,
        projectId: UUID? = nil,
        projectName: String? = nil,
        status: GenerationJobStatus = .planning,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        plan: EditPlan,
        progress: Double = 0.0,
        progressMessage: String = "Review proposed creative plan",
        currentFrame: Int = 0,
        totalFrames: Int = 0,
        outputURL: URL? = nil,
        outputFileSizeFormatted: String? = nil,
        renderDurationSec: Double? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.generationId = generationId ?? "gen_\(id.uuidString.prefix(8))"
        self.artifactId = artifactId ?? "artifact_video_\(id.uuidString.prefix(8))"
        self.projectId = projectId
        self.projectName = projectName
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.plan = plan
        self.progress = progress
        self.progressMessage = progressMessage
        self.currentFrame = currentFrame
        self.totalFrames = totalFrames
        self.outputURL = outputURL
        self.outputFileSizeFormatted = outputFileSizeFormatted
        self.renderDurationSec = renderDurationSec
        self.error = error
    }
    
    var isTerminal: Bool {
        status == .completed || status == .failed
    }
    
    var isActiveRendering: Bool {
        status == .preparing || status == .processing || status == .rendering || status == .exporting || status == .validating
    }
}
