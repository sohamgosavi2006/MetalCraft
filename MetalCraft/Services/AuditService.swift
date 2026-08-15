//
//  AuditService.swift
//  MetalCraft
//
//  Persistent audit logger and historical activity query service.
//  Records structured application lifecycle events, agent planning decisions,
//  Metal GPU render completions, and audio mixing operations to durable disk storage.
//

import Foundation

@MainActor
final class AuditService {
    static let shared = AuditService()
    
    private let fileManager = FileManager.default
    private let maxRecordsRetention = 500
    
    private(set) var records: [AuditRecord] = []
    
    private var auditStorageURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let auditDir = appSupport.appendingPathComponent("Audit", isDirectory: true)
        if !fileManager.fileExists(atPath: auditDir.path) {
            try? fileManager.createDirectory(at: auditDir, withIntermediateDirectories: true)
        }
        return auditDir.appendingPathComponent("audit_log.json")
    }
    
    init() {
        loadAuditLog()
    }
    
    // MARK: - Persistence
    
    private func loadAuditLog() {
        guard fileManager.fileExists(atPath: auditStorageURL.path),
              let data = try? Data(contentsOf: auditStorageURL) else {
            // Seed initial startup record if empty
            let initRecord = AuditRecord(
                category: .system,
                action: "System Initialized",
                status: .info,
                description: "MetalCraft session initialized with active Metal pipeline and Agent services.",
                source: "System Core"
            )
            records = [initRecord]
            saveAuditLog()
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            records = try decoder.decode([AuditRecord].self, from: data)
        } catch {
            print("Failed to decode audit records: \(error)")
            records = []
        }
    }
    
    private func saveAuditLog() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(records)
            try data.write(to: auditStorageURL, options: .atomic)
        } catch {
            print("Failed to save audit log: \(error)")
        }
    }
    
    // MARK: - Recording API
    
    func record(
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
        let entry = AuditRecord(
            category: category,
            action: action,
            status: status,
            projectId: projectId,
            projectName: projectName,
            mediaType: mediaType,
            description: description,
            source: source,
            metadata: metadata
        )
        
        // Prepend so newest is first
        records.insert(entry, at: 0)
        
        // Bound retention
        if records.count > maxRecordsRetention {
            records = Array(records.prefix(maxRecordsRetention))
        }
        
        saveAuditLog()
    }
    
    // MARK: - Query & Filter
    
    func getRecords(
        category: AuditCategory = .all,
        searchQuery: String = "",
        limit: Int = 100
    ) -> [AuditRecord] {
        var filtered = records
        
        if category != .all {
            filtered = filtered.filter { $0.category == category }
        }
        
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchQuery.lowercased()
            filtered = filtered.filter { record in
                record.action.lowercased().contains(query) ||
                record.description.lowercased().contains(query) ||
                (record.projectName?.lowercased().contains(query) ?? false) ||
                record.category.rawValue.lowercased().contains(query) ||
                record.status.rawValue.lowercased().contains(query)
            }
        }
        
        return Array(filtered.prefix(limit))
    }
    
    func clearAuditTrail() {
        records.removeAll()
        saveAuditLog()
        record(
            category: .system,
            action: "Audit Trail Cleared",
            status: .info,
            description: "User cleared all persistent audit records.",
            source: "Audit Service"
        )
    }
}
