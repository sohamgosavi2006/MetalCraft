//
//  ProcessingOperation.swift
//  MetalCraft
//
//  Defines all image processing operations supported by Metal Craft.
//

import Foundation

enum OperationCategory: String, CaseIterable, Codable, Sendable {
    case adjustment = "Adjustments"
    case basic = "Basic"
    case blur = "Blur"
    case sharpen = "Sharpen"
    case edge = "Edge Detection"
    case pixelation = "Pixelation"
    case distortion = "Distortion"
    case convolution = "Convolution Lab"
}

enum ProcessingOperation: Codable, Equatable, Sendable {
    case adjustments(AdjustmentParams)
    case grayscale
    case invert
    case gaussianBlur(sigma: Float)
    case sharpen(strength: Float)
    case sobelEdge(strength: Float, blend: Float)
    case pixelate(blockSize: Float)
    case ripple(RippleConfig)
    case swirl(SwirlConfig)
    case convolution(ConvolutionKernel, strength: Float)
    
    var displayName: String {
        switch self {
        case .adjustments:
            return "Adjustments"
        case .grayscale:
            return "Grayscale"
        case .invert:
            return "Invert"
        case .gaussianBlur:
            return "Gaussian Blur"
        case .sharpen:
            return "Sharpen"
        case .sobelEdge:
            return "Sobel Edge"
        case .pixelate:
            return "Pixelation"
        case .ripple:
            return "Ripple"
        case .swirl:
            return "Swirl"
        case .convolution(let kernel, _):
            return "Convolution (\(kernel.name))"
        }
    }
    
    var iconName: String {
        switch self {
        case .adjustments:
            return "slider.horizontal.3"
        case .grayscale:
            return "circle.lefthalf.filled"
        case .invert:
            return "circle.righthalf.filled.inverse"
        case .gaussianBlur:
            return "drop.fill"
        case .sharpen:
            return "triangle.fill"
        case .sobelEdge:
            return "square.dashed"
        case .pixelate:
            return "square.grid.3x3.fill"
        case .ripple:
            return "water.waves"
        case .swirl:
            return "tornado"
        case .convolution:
            return "grid"
        }
    }
    
    var category: OperationCategory {
        switch self {
        case .adjustments:
            return .adjustment
        case .grayscale, .invert:
            return .basic
        case .gaussianBlur:
            return .blur
        case .sharpen:
            return .sharpen
        case .sobelEdge:
            return .edge
        case .pixelate:
            return .pixelation
        case .ripple, .swirl:
            return .distortion
        case .convolution:
            return .convolution
        }
    }
    
    var parameterSummary: String {
        switch self {
        case .adjustments(let params):
            return "B: \(String(format: "%.1f", params.brightness)) C: \(String(format: "%.1f", params.contrast)) E: \(String(format: "%.1f", params.exposure))"
        case .grayscale:
            return "BT.709 Luminance"
        case .invert:
            return "RGB Color Inversion"
        case .gaussianBlur(let sigma):
            return "σ = \(String(format: "%.1f", sigma))"
        case .sharpen(let strength):
            return "Strength: \(Int(strength * 100))%"
        case .sobelEdge(let strength, let blend):
            return "Strength: \(String(format: "%.1f", strength)), Blend: \(Int(blend * 100))%"
        case .pixelate(let blockSize):
            return "Block: \(Int(blockSize)) px"
        case .ripple(let config):
            return "Freq: \(Int(config.frequency)), Str: \(String(format: "%.2f", config.strength))"
        case .swirl(let config):
            return "Radius: \(String(format: "%.1f", config.radius)), Str: \(String(format: "%.2f", config.strength))"
        case .convolution(let kernel, let strength):
            return "\(kernel.name) (\(Int(strength * 100))%)"
        }
    }
}
