//
//  AICreateView.swift
//  MetalCraft
//
//  Reserved placeholder for future AI-powered creative workflows.
//  Clean empty state with zero simulated or fake functionality.
//

import SwiftUI

struct AICreateView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "wand.and.sparkles")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.tint)
                    .padding(.bottom, 8)
                
                Text("Coming Soon")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text("AI-powered creative editing will be available in a future version of MetalCraft.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .navigationTitle("AI Create")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
