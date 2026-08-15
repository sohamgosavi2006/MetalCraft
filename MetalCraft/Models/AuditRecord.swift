//
//  AuditRecord.swift
//  MetalCraft
//
//  Persistent audit record model capturing structured user and system activity
//  for compliance, historical traceability, and observability.
//

import Foundation

// MARK: - Audit Categories

enum AuditCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case all = "All"
    case project = "Projects"
    case media = "Media"
    case ai = "AI"
    case video = "Video"
    case audio = "Audio"
    case system = "System"
    case errors = "Errors"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .all: return "square.stack.3d.up"
        case .project: return "folder.badge.gearshape"
        case .media: return "photo.on.rectangle.angled"
        case .ai: return "sparkles"
        case .video: return "video.badge.waveform"
        case .audio: return "music.note"
        case .system: return "cpu"
        case .errors: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Audit Status

enum AuditStatus: String, Codable, Sendable {
    case success = "SUCCESS"
    case warning = "WARNING"
    case failure = "FAILURE"
    case info = "INFO"
    
    var badgeColorName: String {
        switch self {
        case .success: return "green"
        case .warning: return "orange"
        case .failure: return "red"
        case .info: return "blue"
        }
    }
}

// MARK: - Audit Record Model

struct AuditRecord: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let category: AuditCategory
    let action: String
    let status: AuditStatus
    let projectId: UUID?
    let projectName: String?
    let mediaType: String?
    let description: String
    let source: String
    let metadata: [String: String]?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: AuditCategory,
        action: String,
        status: AuditStatus = .success,
        projectId: UUID? = nil,
        projectName: String? = nil,
        mediaType: String? = nil,
        description: String,
        source: String = "iOS Client",
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.action = action
        self.status = status
        self.projectId = projectId
        self.projectName = projectName
        self.mediaType = mediaType
        self.description = description
        self.source = source
        self.metadata = metadata
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: timestamp)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(timestamp) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: timestamp)
        }
    }
}
