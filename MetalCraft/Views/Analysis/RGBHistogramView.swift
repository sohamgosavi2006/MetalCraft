//
//  RGBHistogramView.swift
//  MetalCraft
//
//  Composite RGB & Luminance histogram charts with channel toggles.
//

import SwiftUI

struct RGBHistogramView: View {
    let data: HistogramData
    
    @State private var showRed = true
    @State private var showGreen = true
    @State private var showBlue = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // RGB Combined Histogram
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("RGB CHANNEL DISTRIBUTION")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Channel Toggles
                    HStack(spacing: 8) {
                        Toggle("R", isOn: $showRed)
                            .toggleStyle(ChannelToggleStyle(color: .red))
                        Toggle("G", isOn: $showGreen)
                            .toggleStyle(ChannelToggleStyle(color: .green))
                        Toggle("B", isOn: $showBlue)
                            .toggleStyle(ChannelToggleStyle(color: .blue))
                    }
                }
                
                ZStack {
                    if showRed {
                        HistogramView(bins: data.red, color: .red, maxCount: data.maxCount, fillOpacity: 0.3)
                    }
                    if showGreen {
                        HistogramView(bins: data.green, color: .green, maxCount: data.maxCount, fillOpacity: 0.3)
                    }
                    if showBlue {
                        HistogramView(bins: data.blue, color: .blue, maxCount: data.maxCount, fillOpacity: 0.3)
                    }
                }
                .frame(height: 120)
                .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            
            // Luminance Histogram
            VStack(alignment: .leading, spacing: 8) {
                Text("PHOTOMETRIC LUMINANCE (BT.709)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                
                ZStack {
                    HistogramView(bins: data.luminance, color: .white, maxCount: data.maxCount, fillOpacity: 0.4)
                }
                .frame(height: 100)
                .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct ChannelToggleStyle: ToggleStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(configuration.isOn ? color : Color.secondary.opacity(0.3), in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
