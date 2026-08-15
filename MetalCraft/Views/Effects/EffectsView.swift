//
//  EffectsView.swift
//  MetalCraft
//
//  Root view for the Effects tab with compact image preview and categorized effect picker.
//

import SwiftUI

struct EffectsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Mini Preview
                if let image = appState.displayImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.85))
                } else {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 120)
                        .overlay {
                            Label("Import an image to test GPU effects", systemImage: "photo.badge.plus")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }
                
                Divider()
                
                // Categorized Effect Browser
                EffectCategoryList()
            }
            .navigationTitle("Effects Lab")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
