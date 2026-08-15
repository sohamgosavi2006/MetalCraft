//
//  HistogramCalculator.swift
//  MetalCraft
//
//  Calculates 256-bin RGB and Luminance histograms directly from Metal texture pixel data.
//

import Foundation
import Metal

final class HistogramCalculator: Sendable {
    
    /// Reads texture bytes to compute 256-bin RGB and Luminance distributions.
    func calculate(from texture: MTLTexture) async -> HistogramData {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        texture.getBytes(
            &pixelData,
            bytesPerRow: bytesPerRow,
            from: MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: width, height: height, depth: 1)
            ),
            mipmapLevel: 0
        )
        
        // Execute histogram accumulation in a background task
        return await Task.detached(priority: .userInitiated) {
            var data = HistogramData()
            
            // Stride through pixels. Format is BGRA.
            let totalPixels = width * height
            for i in 0..<totalPixels {
                let offset = i * 4
                let b = Int(pixelData[offset])
                let g = Int(pixelData[offset + 1])
                let r = Int(pixelData[offset + 2])
                
                data.red[r] += 1
                data.green[g] += 1
                data.blue[b] += 1
                
                // BT.709 photometric luminance: 0.2126R + 0.7152G + 0.0722B
                let lum = Int(Float(r) * 0.2126 + Float(g) * 0.7152 + Float(b) * 0.0722)
                data.luminance[min(255, max(0, lum))] += 1
            }
            
            return data
        }.value
    }
}
