//
//  ImageInfoView.swift
//  MetalCraft
//
//  Displays technical image metadata (resolution, color channels, bit depth, pixel format).
//

import SwiftUI

struct ImageInfoView: View {
    let info: ImageInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("IMAGE METADATA")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                infoRow(title: "Dimensions", value: "\(info.width) × \(info.height) px")
                Divider()
                infoRow(title: "Megapixels", value: String(format: "%.2f MP", info.megapixels))
                Divider()
                infoRow(title: "Total Pixels", value: "\(info.pixelCount.formatted()) pixels")
                Divider()
                infoRow(title: "Source Format", value: info.format)
                Divider()
                infoRow(title: "Color Channels", value: "4 (BGRA)")
                Divider()
                infoRow(title: "Bit Depth", value: "\(info.bitsPerComponent)-bit per channel (\(info.bitsPerPixel)-bit total)")
                Divider()
                infoRow(title: "Color Space", value: info.colorSpace)
                Divider()
                infoRow(title: "GPU Pixel Format", value: "MTLPixelFormat.bgra8Unorm")
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    @ViewBuilder
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
