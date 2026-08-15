//
//  NewProjectSheet.swift
//  MetalCraft
//
//  Mandatory Project Name creation dialog presented upon media import.
//

import SwiftUI

struct NewProjectSheet: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var projectName: String = ""
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Media Thumbnail Preview
                if let image = appState.pendingImportImage ?? appState.pendingImportVideoThumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Name")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    TextField("e.g. Cinematic Landscape", text: $projectName)
                        .textFieldStyle(.plain)
                        .font(.title3.weight(.medium))
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($isFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            createProject()
                        }
                    
                    if let info = appState.pendingImportInfo {
                        Text("\(info.dimensionsText) • \(info.megapixelsText) • \(info.format)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                    } else if let vInfo = appState.pendingImportVideoInfo {
                        Text("\(vInfo.dimensionsText) • \(vInfo.fpsText) • \(vInfo.formattedDuration)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: createProject) {
                        Text("Create Project")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.accentColor.opacity(0.5) : Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button("Cancel") {
                        appState.pendingImportImage = nil
                        appState.pendingImportTexture = nil
                        appState.pendingImportInfo = nil
                        appState.pendingImportVideoURL = nil
                        appState.pendingImportVideoInfo = nil
                        appState.pendingImportVideoThumbnail = nil
                        appState.showNewProjectSheet = false
                        dismiss()
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
                projectName = "Project \(dateStr)"
                isFieldFocused = true
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func createProject() {
        guard !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        appState.createNewProjectWithPendingMedia(named: projectName)
        dismiss()
    }
}
