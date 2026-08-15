//
//  HistogramView.swift
//  MetalCraft
//
//  Renders a 256-bucket histogram path for a single color/luminance channel.
//

import SwiftUI

struct HistogramView: View {
    let bins: [Int]
    let color: Color
    let maxCount: Int
    var fillOpacity: Double = 0.5
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let binWidth = width / 256.0
            let effectiveMax = max(1, maxCount)
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: height))
                
                for (index, count) in bins.enumerated() {
                    let x = CGFloat(index) * binWidth
                    let normalizedHeight = (CGFloat(count) / CGFloat(effectiveMax)) * height
                    let y = height - normalizedHeight
                    
                    if index == 0 {
                        path.addLine(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(color.opacity(fillOpacity))
            
            // Outline Stroke
            Path { path in
                for (index, count) in bins.enumerated() {
                    let x = CGFloat(index) * binWidth
                    let normalizedHeight = (CGFloat(count) / CGFloat(effectiveMax)) * height
                    let y = height - normalizedHeight
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 1.5)
        }
    }
}
