//
//  SoundtrackMetadata.swift
//  MetalCraft
//
//  Structured soundtrack metadata for MetalCraft's royalty-cleared default audio library.
//  Maintains clear legal provenance, mood, tempo, energy, and tag classification.
//

import Foundation

// MARK: - Soundtrack Category

enum SoundtrackCategory: String, Codable, Sendable, CaseIterable {
    case cinematic = "Cinematic"
    case emotional = "Emotional"
    case energetic = "Energetic"
    case calm = "Calm"
    case corporate = "Corporate"
    case product = "Product"
    case happy = "Happy"
    case travel = "Travel"
    
    var iconName: String {
        switch self {
        case .cinematic: return "film"
        case .emotional: return "heart.fill"
        case .energetic: return "bolt.fill"
        case .calm: return "leaf.fill"
        case .corporate: return "briefcase.fill"
        case .product: return "cube.transparent.fill"
        case .happy: return "sun.max.fill"
        case .travel: return "airplane"
        }
    }
}

// MARK: - Soundtrack Metadata Model

struct SoundtrackMetadata: Identifiable, Codable, Sendable, Equatable {
    let id: String              // controlled track ID (e.g. "cinematic_emotional_01")
    let title: String           // "Celestial Horizons"
    let duration: Double        // in seconds
    let category: SoundtrackCategory
    let mood: String            // "Emotional", "Dramatic", "Upbeat", "Relaxing", etc.
    let energy: String          // "Low", "Medium", "High"
    let tempo: String           // "Andante (76 BPM)", "Allegro (128 BPM)"
    let tags: [String]
    let source: String          // "MetalCraft Sound Labs"
    let license: String         // "Royalty-Free / MetalCraft Open Distribution License"
    let attributionRequired: Bool
    let filename: String
    
    init(
        id: String,
        title: String,
        duration: Double,
        category: SoundtrackCategory,
        mood: String,
        energy: String,
        tempo: String,
        tags: [String],
        source: String = "MetalCraft Sound Labs",
        license: String = "Royalty-Free Creative Commons Zero (CC0)",
        attributionRequired: Bool = false,
        filename: String
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.category = category
        self.mood = mood
        self.energy = energy
        self.tempo = tempo
        self.tags = tags
        self.source = source
        self.license = license
        self.attributionRequired = attributionRequired
        self.filename = filename
    }
    
    var formattedDuration: String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
