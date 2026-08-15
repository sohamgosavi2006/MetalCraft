//
//  HistogramData.swift
//  MetalCraft
//
//  Models for 256-bin RGB and Luminance histograms, plus image metadata.
//

import Foundation

struct HistogramData: Sendable, Equatable, Codable {
    var red: [Int] = Array(repeating: 0, count: 256)
    var green: [Int] = Array(repeating: 0, count: 256)
    var blue: [Int] = Array(repeating: 0, count: 256)
    var luminance: [Int] = Array(repeating: 0, count: 256)
    
    var maxCount: Int {
        let rMax = red.max() ?? 0
        let gMax = green.max() ?? 0
        let bMax = blue.max() ?? 0
        let lMax = luminance.max() ?? 0
        return max(rMax, gMax, bMax, lMax, 1)
    }
}

struct ImageInfo: Sendable, Equatable, Codable {
    let width: Int
    let height: Int
    let pixelCount: Int
    let format: String
    let colorChannels: Int
    let bitsPerComponent: Int
    let bitsPerPixel: Int
    let colorSpace: String
    
    var megapixels: Double {
        Double(pixelCount) / 1_000_000.0
    }
    
    var dimensionsDescription: String {
        "\(width) × \(height) px (\(String(format: "%.2f", megapixels)) MP)"
    }
    
    var dimensionsText: String {
        "\(width) × \(height) px"
    }
    
    var megapixelsText: String {
        String(format: "%.2f MP", megapixels)
    }
}
