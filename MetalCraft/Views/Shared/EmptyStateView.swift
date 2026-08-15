//
//  EmptyStateView.swift
//  MetalCraft
//
//  Reusable empty state placeholder shown when no image is loaded
//  or no data is available for a given section.
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "photo.badge.plus")
                        .font(.body.weight(.medium))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        icon: "photo.badge.plus",
        title: "No Image",
        subtitle: "Import an image to begin GPU processing",
        actionTitle: "Import Image",
        action: {}
    )
}
