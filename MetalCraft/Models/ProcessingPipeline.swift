//
//  ProcessingPipeline.swift
//  MetalCraft
//
//  Manages the ordered sequence of processing operations.
//

import Foundation
import SwiftUI

struct ProcessingPipeline: Codable, Equatable, Sendable {
    var nodes: [PipelineNode] = []
    
    var enabledNodes: [PipelineNode] {
        nodes.filter { $0.isEnabled }
    }
    
    var isEmpty: Bool {
        nodes.isEmpty
    }
    
    mutating func addNode(_ node: PipelineNode) {
        nodes.append(node)
    }
    
    mutating func insertNode(_ node: PipelineNode, at index: Int) {
        nodes.insert(node, at: index)
    }
    
    mutating func removeNode(id: UUID) {
        nodes.removeAll { $0.id == id }
    }
    
    mutating func removeNodes(at offsets: IndexSet) {
        nodes.remove(atOffsets: offsets)
    }
    
    mutating func moveNodes(from source: IndexSet, to destination: Int) {
        nodes.move(fromOffsets: source, toOffset: destination)
    }
    
    mutating func toggleNode(id: UUID) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].isEnabled.toggle()
        }
    }
    
    mutating func updateNode(_ node: PipelineNode) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index] = node
        }
    }
    
    mutating func reset() {
        nodes.removeAll()
    }
    
    // MARK: - Built-in Preset Pipelines
    
    static let cinematic = ProcessingPipeline(nodes: [
        PipelineNode(operation: .adjustments(AdjustmentParams(
            brightness: -0.05, contrast: 1.3, exposure: 0.15,
            saturation: 0.85, temperature: 0.15, tint: -0.05, gamma: 1.1,
            _padding: 0.0
        )))
    ])
    
    static let warm = ProcessingPipeline(nodes: [
        PipelineNode(operation: .adjustments(AdjustmentParams(
            brightness: 0.05, contrast: 1.05, exposure: 0.1,
            saturation: 1.2, temperature: 0.3, tint: 0.05, gamma: 1.0,
            _padding: 0.0
        )))
    ])
    
    static let highContrast = ProcessingPipeline(nodes: [
        PipelineNode(operation: .adjustments(AdjustmentParams(
            brightness: 0.0, contrast: 1.8, exposure: 0.0,
            saturation: 1.25, temperature: 0.0, tint: 0.0, gamma: 0.9,
            _padding: 0.0
        )))
    ])
    
    static let blackAndWhite = ProcessingPipeline(nodes: [
        PipelineNode(operation: .adjustments(AdjustmentParams(
            brightness: 0.02, contrast: 1.25, exposure: 0.0,
            saturation: 1.0, temperature: 0.0, tint: 0.0, gamma: 1.0,
            _padding: 0.0
        ))),
        PipelineNode(operation: .grayscale)
    ])
    
    static let sharpened = ProcessingPipeline(nodes: [
        PipelineNode(operation: .adjustments(AdjustmentParams(
            brightness: 0.0, contrast: 1.1, exposure: 0.0,
            saturation: 1.05, temperature: 0.0, tint: 0.0, gamma: 1.0,
            _padding: 0.0
        ))),
        PipelineNode(operation: .sharpen(strength: 0.75))
    ])
}
