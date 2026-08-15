//
//  ComparisonMode.swift
//  MetalCraft
//
//  Viewport comparison modes for comparing original vs processed textures.
//

import Foundation

enum ComparisonMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case processed = "Processed"
    case original = "Original"
    case sideBySide = "Side-by-Side"
    case split = "Split"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .processed:
            return "sparkles"
        case .original:
            return "photo"
        case .sideBySide:
            return "rectangle.split.2x1"
        case .split:
            return "arrow.left.and.right.square"
        }
    }
}
