//
//  PresetsControlView.swift
//  MetalCraft
//
//  Inline Presets control panel for the Editor workspace.
//  Presents Built-in and Custom presets with 1-tap application,
//  and quick "Save Current Pipeline as Preset" action.
//

import SwiftUI

struct PresetsControlView: View {
    @Environment(AppState.self) private var appState
    
    @State private var showingSaveAlert = false
    @State private var newPresetName = ""
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // Save Current as Preset Button
                Button {
                    newPresetName = ""
                    showingSaveAlert = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Save Current Pipeline as Preset")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(appState.originalImage == nil || (appState.pipeline.isEmpty && appState.activeAdjustments.isDefault))
                .accessibilityLabel("Save Current Pipeline as Preset")
                
                // Built-in Presets Section
                Text("BUILT-IN PRESETS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 10)], spacing: 10) {
                    ForEach(appState.presets.filter { $0.isBuiltIn }) { preset in
                        presetCard(preset: preset)
                    }
                }
                
                // Custom User Presets Section
                let customPresets = appState.presets.filter { !$0.isBuiltIn }
                if !customPresets.isEmpty {
                    Text("CUSTOM PRESETS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 10)], spacing: 10) {
                        ForEach(customPresets) { preset in
                            presetCard(preset: preset)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
        .alert("Save Preset", isPresented: $showingSaveAlert) {
            TextField("Preset Name", text: $newPresetName)
            Button("Save") {
                let trimmed = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    appState.saveCurrentAsPreset(name: trimmed)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the current pipeline and adjustments configuration.")
        }
    }
    
    @ViewBuilder
    private func presetCard(preset: Preset) -> some View {
        Button {
            appState.applyPreset(preset)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: preset.isBuiltIn ? "wand.and.stars" : "slider.horizontal.3")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    if !preset.isBuiltIn {
                        Button {
                            appState.deletePreset(preset)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(preset.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text("\(preset.pipeline.nodes.count) Operations")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.name) preset")
    }
}
