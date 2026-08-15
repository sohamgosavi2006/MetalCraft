//
//  PresetPickerSheet.swift
//  MetalCraft
//
//  Sheet to browse, apply, save, and delete pipeline presets.
//

import SwiftUI

struct PresetPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingSaveAlert = false
    @State private var newPresetName = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("Built-in Presets") {
                    ForEach(appState.presets.filter { $0.isBuiltIn }) { preset in
                        Button {
                            appState.applyPreset(preset)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("\(preset.pipeline.nodes.count) operations")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "wand.and.stars")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
                
                let customPresets = appState.presets.filter { !$0.isBuiltIn }
                Section("My Custom Presets") {
                    if customPresets.isEmpty {
                        Text("No custom presets saved yet. Save your current pipeline below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(customPresets) { preset in
                            Button {
                                appState.applyPreset(preset)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preset.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(preset.dateCreated, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                appState.deletePreset(customPresets[index])
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        newPresetName = ""
                        showingSaveAlert = true
                    } label: {
                        Label("Save Current Pipeline as Preset", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.tint)
                    }
                    .disabled(appState.originalImage == nil || (appState.pipeline.isEmpty && appState.activeAdjustments.isDefault))
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Save Preset", isPresented: $showingSaveAlert) {
                TextField("Preset Name", text: $newPresetName)
                Button("Save") {
                    if !newPresetName.trimmingCharacters(in: .whitespaces).isEmpty {
                        appState.saveCurrentAsPreset(name: newPresetName.trimmingCharacters(in: .whitespaces))
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for the current pipeline and adjustments configuration.")
            }
        }
    }
}
