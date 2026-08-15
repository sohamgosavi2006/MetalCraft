//
//  AgentState.swift
//  MetalCraft
//
//  Models and state representations for the Gemini Creative Director agent,
//  including runtime lifecycle states, conversational messages, and execution context.
//

import Foundation

// MARK: - Agent State Lifecycle

enum AgentState: String, Codable, Sendable, CaseIterable {
    case idle = "Idle"
    case analyzing = "Analyzing Media"
    case researching = "Researching Context"
    case planning = "Formulating EditPlan"
    case validating = "Validating Operations"
    case waitingForApproval = "Waiting for User Approval"
    case executing = "Executing on GPU"
    case observing = "Observing Telemetry"
    case evaluating = "Evaluating Output"
    case revising = "Revising Plan"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
    case timeout = "Timeout"
    
    var isBusy: Bool {
        switch self {
        case .analyzing, .researching, .planning, .validating, .executing, .observing, .evaluating, .revising:
            return true
        case .idle, .waitingForApproval, .completed, .failed, .cancelled, .timeout:
            return false
        }
    }
    
    var systemIcon: String {
        switch self {
        case .idle: return "wand.and.sparkles"
        case .analyzing: return "waveform.path.badge.magnifyingglass"
        case .researching: return "book.pages"
        case .planning: return "brain.head.profile"
        case .validating: return "checkmark.shield"
        case .waitingForApproval: return "person.crop.circle.badge.questionmark"
        case .executing: return "bolt.fill"
        case .observing: return "chart.xyaxis.line"
        case .evaluating: return "eye.circle"
        case .revising: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .timeout: return "clock.badge.exclamationmark"
        }
    }
}

// MARK: - Agent Role

enum AgentRole: String, Codable, Sendable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    case researcher = "researcher"
    case observer = "observer"
}

// MARK: - Agent Message

struct AgentMessage: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var role: AgentRole
    var content: String
    var reasoning: String?
    var researchContext: String?
    var editPlan: EditPlan?
    var timestamp: Date
    
    init(
        id: UUID = UUID(),
        role: AgentRole,
        content: String,
        reasoning: String? = nil,
        researchContext: String? = nil,
        editPlan: EditPlan? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.reasoning = reasoning
        self.researchContext = researchContext
        self.editPlan = editPlan
        self.timestamp = timestamp
    }
}
