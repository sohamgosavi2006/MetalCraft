//
//  PipelineNode.swift
//  MetalCraft
//
//  Represents a single node within the non-destructive processing pipeline.
//

import Foundation

struct PipelineNode: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var operation: ProcessingOperation
    var isEnabled: Bool
    
    init(id: UUID = UUID(), operation: ProcessingOperation, isEnabled: Bool = true) {
        self.id = id
        self.operation = operation
        self.isEnabled = isEnabled
    }
}
