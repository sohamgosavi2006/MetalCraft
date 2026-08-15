//
//  ProjectDetailsView.swift
//  MetalCraft
//
//  Detailed multi-image and multi-video document browser for a Project.
//  Presents distinct Images and Videos sections, allows importing media,
//  and previews/opens selected media in the Editor.
//

import SwiftUI
import PhotosUI

struct ProjectDetailsView: View {
    @Bindable var appState: AppState
    let project: Project
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingRenameAlert = false
    @State private var newProjectName = ""
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedVideoItems: [PhotosPickerItem] = []
    @State private var selectedImageForPreview: ProjectImage? = nil
    @State private var selectedVideoForPreview: ProjectVideo? = nil
    
    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 14)
    ]
    
    private var currentProjectData: Project {
        appState.projects.first(where: { $0.id == project.id }) ?? project
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Project Header Info Card
                    projectHeaderCard
                    
                    // MARK: - Images Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("IMAGES")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Text("\(currentProjectData.images.count) \(currentProjectData.images.count == 1 ? "Image" : "Images")")
                                    .font(.subheadline.weight(.semibold))
                            }
                            
                            Spacer()
                            
                            PhotosPicker(selection: $selectedPhotoItems, matching: .images, photoLibrary: .shared()) {
                                Label("Add Image", systemImage: "photo.badge.plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .accessibilityLabel("Add Image to Project")
                        }
                        .padding(.horizontal)
                        
                        if currentProjectData.images.isEmpty {
                            emptySectionPlaceholder(title: "No Images in Project", subtitle: "Tap 'Add Image' to import photos.")
                        } else {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(currentProjectData.images) { img in
                                    ProjectImageGridItem(
                                        projectId: currentProjectData.id,
                                        image: img,
                                        appState: appState,
                                        onTap: {
                                            selectedImageForPreview = img
                                        },
                                        onOpenDirectly: {
                                            appState.openProject(currentProjectData, image: img)
                                            dismiss()
                                        },
                                        onDelete: {
                                            appState.deleteImage(img, from: currentProjectData)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // MARK: - Videos Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("VIDEOS")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Text("\(currentProjectData.videos.count) \(currentProjectData.videos.count == 1 ? "Video" : "Videos")")
                                    .font(.subheadline.weight(.semibold))
                            }
                            
                            Spacer()
                            
                            PhotosPicker(selection: $selectedVideoItems, matching: .videos, photoLibrary: .shared()) {
                                Label("Add Video", systemImage: "video.badge.plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .accessibilityLabel("Add Video to Project")
                        }
                        .padding(.horizontal)
                        
                        if currentProjectData.videos.isEmpty {
                            emptySectionPlaceholder(title: "No Videos in Project", subtitle: "Tap 'Add Video' to import video clips.")
                        } else {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(currentProjectData.videos) { vid in
                                    ProjectVideoGridItem(
                                        projectId: currentProjectData.id,
                                        video: vid,
                                        appState: appState,
                                        onTap: {
                                            selectedVideoForPreview = vid
                                        },
                                        onOpenDirectly: {
                                            appState.openProject(currentProjectData, video: vid)
                                            dismiss()
                                        },
                                        onDelete: {
                                            appState.deleteVideo(vid, from: currentProjectData)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(currentProjectData.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        appState.toggleProjectFavorite(currentProjectData)
                    } label: {
                        Image(systemName: currentProjectData.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(currentProjectData.isFavorite ? .yellow : .primary)
                    }
                    .accessibilityLabel("Favorite Project")
                    
                    Menu {
                        Button {
                            newProjectName = currentProjectData.name
                            showingRenameAlert = true
                        } label: {
                            Label("Rename Project", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            appState.deleteProject(currentProjectData)
                            dismiss()
                        } label: {
                            Label("Delete Project", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                if !newItems.isEmpty {
                    Task {
                        for item in newItems {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                appState.addImage(to: currentProjectData, uiImage: uiImage)
                            }
                        }
                        selectedPhotoItems = []
                    }
                }
            }
            .onChange(of: selectedVideoItems) { _, newItems in
                if !newItems.isEmpty {
                    Task {
                        for item in newItems {
                            if let (tempURL, info, thumb) = try? await appState.videoManager.importVideo(from: item) {
                                appState.addVideo(to: currentProjectData, tempURL: tempURL, info: info, thumbnail: thumb)
                            }
                        }
                        selectedVideoItems = []
                    }
                }
            }
            .sheet(item: $selectedImageForPreview) { img in
                ImagePreviewSheet(
                    appState: appState,
                    project: currentProjectData,
                    image: img
                )
            }
            .sheet(item: $selectedVideoForPreview) { vid in
                VideoPreviewSheet(
                    appState: appState,
                    project: currentProjectData,
                    video: vid
                )
            }
            .alert("Rename Project", isPresented: $showingRenameAlert) {
                TextField("Project Name", text: $newProjectName)
                Button("Save") {
                    appState.renameProject(currentProjectData, newName: newProjectName)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    // MARK: - Header Info Card
    
    private var projectHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentProjectData.name)
                        .font(.headline)
                    Text("Created \(currentProjectData.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if currentProjectData.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }
            
            Divider()
            
            HStack {
                Text("Last Modified")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currentProjectData.formattedModifiedDate)
                    .font(.caption.weight(.medium))
            }
            
            HStack {
                Text("Total Media")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currentProjectData.mediaSummaryText)
                    .font(.caption.weight(.medium))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
    
    // MARK: - Empty Section Placeholder
    
    private func emptySectionPlaceholder(title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

// MARK: - Project Image Grid Item

private struct ProjectImageGridItem: View {
    let projectId: UUID
    let image: ProjectImage
    let appState: AppState
    let onTap: () -> Void
    let onOpenDirectly: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
                    .aspectRatio(1.0, contentMode: .fit)
                
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.0, contentMode: .fit)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .onTapGesture {
                onTap()
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(image.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                
                if let info = image.imageInfo {
                    Text(info.dimensionsText)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button(action: onOpenDirectly) {
                Label("Open in Editor", systemImage: "slider.horizontal.3")
            }
            Button(action: onTap) {
                Label("Preview Image", systemImage: "eye")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete Image", systemImage: "trash")
            }
        }
        .task {
            thumbnail = appState.projectManager.loadPreviewImage(projectId: projectId, image: image) ?? appState.projectManager.loadOriginalImage(projectId: projectId, image: image)
        }
    }
}

// MARK: - Project Video Grid Item (with Play icon & Duration badge)

private struct ProjectVideoGridItem: View {
    let projectId: UUID
    let video: ProjectVideo
    let appState: AppState
    let onTap: () -> Void
    let onOpenDirectly: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.8))
                        .aspectRatio(1.0, contentMode: .fit)
                    
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1.0, contentMode: .fit)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    }
                    
                    // Center Play Badge
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.5), radius: 4)
                }
                
                // Bottom Duration Tag
                if let info = video.videoInfo {
                    Text(info.formattedDuration)
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
            .onTapGesture {
                onTap()
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(video.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                
                if let info = video.videoInfo {
                    Text(info.dimensionsText)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button(action: onOpenDirectly) {
                Label("Open in Editor", systemImage: "slider.horizontal.3")
            }
            Button(action: onTap) {
                Label("Preview Video", systemImage: "eye")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete Video", systemImage: "trash")
            }
        }
        .task {
            thumbnail = appState.projectManager.loadVideoThumbnail(projectId: projectId, video: video)
        }
    }
}
