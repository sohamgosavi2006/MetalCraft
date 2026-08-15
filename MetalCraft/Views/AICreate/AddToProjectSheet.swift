//
//  AddToProjectSheet.swift
//  MetalCraft
//
//  Sheet allowing the user to attach a generated AI video artifact directly to
//  an existing Project or create a new Project on the fly with the video asset.
//

import SwiftUI

struct AddToProjectSheet: View {
    @Bindable var appState: AppState
    let artifact: VideoArtifact
    let onComplete: (Project) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var isCreatingNewProject: Bool = false
    @State private var newProjectName: String = ""
    @State private var selectedProjectId: UUID?
    @State private var isProcessing: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Video Header Preview Info
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "film.stack.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                            .frame(width: 36, height: 36)
                            .background(Color.purple.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(artifact.displayName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            
                            Text("\(String(format: "%.1f", artifact.duration))s • \(artifact.width)×\(artifact.height) • \(artifact.formattedFileSize)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                // Existing Projects List
                Section("Select Target Project") {
                    if appState.projects.isEmpty {
                        Text("No existing projects found. Create one below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.projects) { project in
                            Button {
                                addArtifact(to: project)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(project.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                        
                                        Text("\(project.images.count) photos • \(project.videos.count) videos")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if project.id == appState.currentProject?.id {
                                        Text("Current")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.purple.opacity(0.15))
                                            .foregroundStyle(.purple)
                                            .clipShape(Capsule())
                                    }
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
                
                // Create New Project Flow
                Section("Or Create New Project") {
                    if isCreatingNewProject {
                        HStack {
                            TextField("Project Name", text: $newProjectName)
                                .font(.subheadline)
                            
                            Button("Create & Add") {
                                createAndAddProject()
                            }
                            .font(.subheadline.weight(.semibold))
                            .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                        }
                    } else {
                        Button {
                            newProjectName = "\(artifact.displayName) Project"
                            isCreatingNewProject = true
                        } label: {
                            Label("Create New Project", systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.purple)
                        }
                    }
                }
            }
            .navigationTitle("Add Video to Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addArtifact(to project: Project) {
        guard !isProcessing else { return }
        isProcessing = true
        
        let (updatedProject, _) = appState.projectManager.importArtifactToProject(
            artifact: artifact,
            project: project
        )
        
        // Update AppState projects
        appState.projects = appState.projectManager.loadAllProjects()
        if appState.currentProject?.id == updatedProject.id {
            appState.currentProject = updatedProject
        }
        
        // Record Audit & Telemetry
        AuditService.shared.record(
            category: .project,
            action: "Video Added to Project",
            status: .success,
            projectId: updatedProject.id,
            projectName: updatedProject.name,
            mediaType: "Video",
            description: "Added AI generated video '\(artifact.displayName)' to '\(updatedProject.name)'.",
            source: "AI Studio"
        )
        
        appState.telemetryService.emit(TelemetryEvent(
            eventType: TelemetryEventType.videoAddedToProject.rawValue,
            sessionId: appState.telemetryService.sessionId,
            generationId: artifact.generationId,
            artifactId: artifact.artifactId,
            operation: "Import Video to Project"
        ))
        
        onComplete(updatedProject)
        dismiss()
    }
    
    private func createAndAddProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isProcessing else { return }
        isProcessing = true
        
        var newProject = Project(name: name)
        let (savedProject, _) = appState.projectManager.importArtifactToProject(
            artifact: artifact,
            project: newProject
        )
        
        appState.projects = appState.projectManager.loadAllProjects()
        appState.currentProject = savedProject
        
        AuditService.shared.record(
            category: .project,
            action: "Project Created With Video",
            status: .success,
            projectId: savedProject.id,
            projectName: savedProject.name,
            mediaType: "Video",
            description: "Created project '\(savedProject.name)' from AI generated video '\(artifact.displayName)'.",
            source: "AI Studio"
        )
        
        appState.telemetryService.emit(TelemetryEvent(
            eventType: TelemetryEventType.videoAddedToProject.rawValue,
            sessionId: appState.telemetryService.sessionId,
            generationId: artifact.generationId,
            artifactId: artifact.artifactId,
            operation: "Create Project with Video"
        ))
        
        onComplete(savedProject)
        dismiss()
    }
}
