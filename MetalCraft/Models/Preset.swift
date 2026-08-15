//
//  Preset.swift
//  MetalCraft
//
//  Pipeline preset model supporting built-in and user-created custom presets.
//

import Foundation

struct Preset: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    var name: String
    var pipeline: ProcessingPipeline
    var dateCreated: Date
    var isBuiltIn: Bool
    
    init(id: UUID = UUID(), name: String, pipeline: ProcessingPipeline, dateCreated: Date = Date(), isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.pipeline = pipeline
        self.dateCreated = dateCreated
        self.isBuiltIn = isBuiltIn
    }
    
    static let builtInPresets: [Preset] = [
        Preset(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "Cinematic", pipeline: .cinematic, dateCreated: .distantPast, isBuiltIn: true),
        Preset(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "Warm Sunlight", pipeline: .warm, dateCreated: .distantPast, isBuiltIn: true),
        Preset(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, name: "High Contrast", pipeline: .highContrast, dateCreated: .distantPast, isBuiltIn: true),
        Preset(id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, name: "Monochrome Pro", pipeline: .blackAndWhite, dateCreated: .distantPast, isBuiltIn: true),
        Preset(id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!, name: "Crisp Detail", pipeline: .sharpened, dateCreated: .distantPast, isBuiltIn: true)
    ]
}
