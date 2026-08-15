//
//  ProjectPickerSheet.swift
//  MetalCraft
//
//  Quick project and media selection sheet allowing users to open existing
//  project images or videos directly from the Editor workspace.
//

import SwiftUI

struct ProjectPickerSheet: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if appState.projects.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No Projects Found")
                            .font(.headline)
                        Text("Create a new project by importing a photo or video.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding()
                } else {
                    List {
                        ForEach(appState.projects) { project in
                            Section {
                                if project.images.isEmpty && project.videos.isEmpty {
                                    Text("No media in this project")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    // Images
                                    ForEach(project.images) { image in
                                        Button {
                                            appState.openProject(project, image: image)
                                            dismiss()
                                        } label: {
                                            HStack(spacing: 12) {
                                                projectImageThumbnail(projectId: project.id, image: image)
                                                
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(image.name)
                                                        .font(.headline)
                                                        .foregroundStyle(.primary)
                                                    
                                                    HStack {
                                                        if let info = image.imageInfo {
                                                            Text(info.dimensionsText)
                                                                .font(.caption2)
                                                                .foregroundStyle(.secondary)
                                                        }
                                                        Text("• Image")
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                if appState.currentProject?.id == project.id && appState.currentProjectImage?.id == image.id && appState.activeMediaType == .image {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(Color.accentColor)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    // Videos
                                    ForEach(project.videos) { video in
                                        Button {
                                            appState.openProject(project, video: video)
                                            dismiss()
                                        } label: {
                                            HStack(spacing: 12) {
                                                projectVideoThumbnail(projectId: project.id, video: video)
                                                
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(video.name)
                                                        .font(.headline)
                                                        .foregroundStyle(.primary)
                                                    
                                                    HStack {
                                                        if let info = video.videoInfo {
                                                            Text(info.formattedDuration)
                                                                .font(.caption2.weight(.bold))
                                                                .foregroundStyle(Color.accentColor)
                                                            Text("• \(info.dimensionsText)")
                                                                .font(.caption2)
                                                                .foregroundStyle(.secondary)
                                                        }
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                if appState.currentProject?.id == project.id && appState.currentProjectVideo?.id == video.id && appState.activeMediaType == .video {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(Color.accentColor)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            } header: {
                                HStack {
                                    if project.isFavorite {
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(.yellow)
                                    }
                                    Text(project.name)
                                        .font(.headline)
                                    Spacer()
                                    Text(project.mediaSummaryText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Open Project Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    @ViewBuilder
    private func projectImageThumbnail(projectId: UUID, image: ProjectImage) -> some View {
        if let thumb = appState.projectManager.loadPreviewImage(projectId: projectId, image: image) ?? appState.projectManager.loadOriginalImage(projectId: projectId, image: image) {
            Image(uiImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                )
        }
    }
    
    @ViewBuilder
    private func projectVideoThumbnail(projectId: UUID, video: ProjectVideo) -> some View {
        if let thumb = appState.projectManager.loadVideoThumbnail(projectId: projectId, video: video) {
            ZStack {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Image(systemName: "play.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.8))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "video.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                )
        }
    }
}
