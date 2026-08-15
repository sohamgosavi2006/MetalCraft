//
//  ExportFormat.swift
//  MetalCraft
//
//  Supported image export file formats and uniform type identifiers.
//

import Foundation
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg = "JPEG"
    case png = "PNG"
    case heif = "HEIF"
    
    var id: String { rawValue }
    
    var utType: UTType {
        switch self {
        case .jpeg:
            return .jpeg
        case .png:
            return .png
        case .heif:
            return .heic
        }
    }
    
    var fileExtension: String {
        switch self {
        case .jpeg:
            return "jpg"
        case .png:
            return "png"
        case .heif:
            return "heic"
        }
    }
    
    var mimeType: String {
        switch self {
        case .jpeg:
            return "image/jpeg"
        case .png:
            return "image/png"
        case .heif:
            return "image/heic"
        }
    }
}
