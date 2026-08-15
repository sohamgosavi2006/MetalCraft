//
//  ProjectDetailsView.swift
//  MetalCraft
//
//  Rich Detail View for a single Project.
//  Displays metadata, image grids, video clips, and soundtrack music tracks with:
//  - Renaming support for project, photos, videos, and music
//  - Direct Open in Editor
//  - Quick fullscreen preview sheets
//  - Multi-photo & video importer
//  - Direct soundtrack audio file importer (.m4a, .mp3, .wav)
//  - Audio preview player & preferred soundtrack toggle
//

import SwiftUI
import PhotosUI

struct ProjectDetailsView: View {
    let appState: AppState
    let project: Project
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedVideoItems: [PhotosPickerItem] = []
    @State private var isShowingAudioImporter: Bool = false
    @State private var selectedImageForPreview: ProjectImage? = nil
    @State private var selectedVideoForPreview: ProjectVideo? = nil
    @State private var showingRenameAlert = false
    @State private var newProjectName = ""
    
    // Media Renaming State
    @State private var itemToRename: (type: String, id: UUID, name: String)? = nil
    @State private var mediaRenameText: String = ""
    @State private var showingMediaRenameAlert: Bool = false
    
    private var currentProjectData: Project {
        appState.projects.first(where: { $0.id == project.id }) ?? project
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 14)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    projectInfoCard
                    
                    Divider()
                        .padding(.horizontal)
                    
                    imagesSection
                    
                    Divider()
                        .padding(.horizontal)
                    
                    videosSection
                    
                    Divider()
                        .padding(.horizontal)
                    
                    musicSection
                }
                .padding(.vertical)
            }
            .navigationTitle(currentProjectData.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        appState.stopAudioPreview()
                        dismiss()
                    }
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
            .fileImporter(
                isPresented: $isShowingAudioImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            _ = await appState.addMusicToProject(url: url, to: currentProjectData)
                        }
                    }
                case .failure(let error):
                    print("Audio file import failed: \(error.localizedDescription)")
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
            .alert("Rename \(itemToRename?.type ?? "Media")", isPresented: $showingMediaRenameAlert) {
                TextField("Name", text: $mediaRenameText)
                Button("Save") {
                    guard let item = itemToRename else { return }
                    if item.type == "Photo" {
                        if let img = currentProjectData.images.first(where: { $0.id == item.id }) {
                            appState.renameImage(in: currentProjectData, image: img, newName: mediaRenameText)
                        }
                    } else if item.type == "Video" {
                        if let vid = currentProjectData.videos.first(where: { $0.id == item.id }) {
                            appState.renameVideo(in: currentProjectData, video: vid, newName: mediaRenameText)
                        }
                    } else if item.type == "Music" {
                        if let mus = currentProjectData.music.first(where: { $0.id == item.id }) {
                            appState.renameMusic(in: currentProjectData, music: mus, newName: mediaRenameText)
                        }
                    }
                    itemToRename = nil
                }
                Button("Cancel", role: .cancel) {
                    itemToRename = nil
                }
            }
        }
    }
    
    // MARK: - Images Section
    
    @ViewBuilder
    private var imagesSection: some View {
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
                            onRename: {
                                itemToRename = (type: "Photo", id: img.id, name: img.name)
                                mediaRenameText = img.name
                                showingMediaRenameAlert = true
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
    }
    
    // MARK: - Videos Section
    
    @ViewBuilder
    private var videosSection: some View {
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
                            onRename: {
                                itemToRename = (type: "Video", id: vid.id, name: vid.name)
                                mediaRenameText = vid.name
                                showingMediaRenameAlert = true
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
    
    // MARK: - Music & Soundtracks Section
    
    @ViewBuilder
    private var musicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MUSIC & SOUNDTRACKS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("\(currentProjectData.music.count) \(currentProjectData.music.count == 1 ? "Track" : "Tracks")")
                        .font(.subheadline.weight(.semibold))
                }
                
                Spacer()
                
                Button {
                    isShowingAudioImporter = true
                } label: {
                    Label("Add Music", systemImage: "music.note.badge.plus")
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityLabel("Add Music to Project")
            }
            .padding(.horizontal)
            
            if currentProjectData.music.isEmpty {
                emptySectionPlaceholder(title: "No Music in Project", subtitle: "Tap 'Add Music' to import .m4a, .mp3, or .wav soundtracks.")
            } else {
                VStack(spacing: 8) {
                    ForEach(currentProjectData.music) { track in
                        ProjectMusicRowItem(
                            projectId: currentProjectData.id,
                            music: track,
                            appState: appState,
                            onTogglePreferred: {
                                appState.toggleMusicPreferred(track, in: currentProjectData)
                            },
                            onRename: {
                                itemToRename = (type: "Music", id: track.id, name: track.name)
                                mediaRenameText = track.name
                                showingMediaRenameAlert = true
                            },
                            onDelete: {
                                appState.deleteMusicFromProject(track, from: currentProjectData)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Project Info Card
    
    private var projectInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentProjectData.name)
                        .font(.headline.weight(.bold))
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
    let onRename: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(10)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 120)
                        .overlay {
                            ProgressView()
                        }
                }
                
                if image.activeOperationCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8))
                        Text("\(image.activeOperationCount)")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
                    .padding(6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            
            Text(image.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            
            Text(image.imageInfo?.dimensionsText ?? "Image")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contextMenu {
            Button {
                onRename()
            } label: {
                Label("Rename Photo", systemImage: "pencil")
            }
            
            Button {
                onOpenDirectly()
            } label: {
                Label("Open in Editor", systemImage: "pencil.and.outline")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Image", systemImage: "trash")
            }
        }
        .task {
            if thumbnail == nil {
                thumbnail = appState.projectManager.loadOriginalImage(projectId: projectId, image: image)
            }
        }
    }
}

// MARK: - Project Video Grid Item

private struct ProjectVideoGridItem: View {
    let projectId: UUID
    let video: ProjectVideo
    let appState: AppState
    let onTap: () -> Void
    let onOpenDirectly: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(10)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 120)
                        .overlay {
                            Image(systemName: "video.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                }
                
                if let durationText = video.videoInfo?.formattedDuration {
                    Text(durationText)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.75))
                        .foregroundStyle(.white)
                        .cornerRadius(4)
                        .padding(6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            
            Text(video.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            
            Text("\(video.videoInfo?.dimensionsText ?? "Video") • \(video.videoInfo?.fpsText ?? "")")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contextMenu {
            Button {
                onRename()
            } label: {
                Label("Rename Video", systemImage: "pencil")
            }
            
            Button {
                onOpenDirectly()
            } label: {
                Label("Open in Editor", systemImage: "pencil.and.outline")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Video", systemImage: "trash")
            }
        }
        .task {
            if thumbnail == nil {
                thumbnail = appState.projectManager.loadVideoThumbnail(projectId: projectId, video: video)
            }
        }
    }
}

// MARK: - Project Music Row Item

private struct ProjectMusicRowItem: View {
    let projectId: UUID
    let music: ProjectMusic
    let appState: AppState
    let onTogglePreferred: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    private var isPlaying: Bool {
        if let currentURL = appState.currentlyPlayingTrackURL,
           let trackURL = appState.projectManager.loadMusicURL(projectId: projectId, music: music) {
            return appState.isPlayingAudioPreview && currentURL == trackURL
        }
        return false
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                if let url = appState.projectManager.loadMusicURL(projectId: projectId, music: music) {
                    appState.toggleAudioPreview(url: url)
                }
            } label: {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(music.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    if music.isPreferred {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                
                Text("\(music.formattedDuration) • \(music.format.uppercased()) • \(music.fileSizeFormatted)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                onTogglePreferred()
            } label: {
                Image(systemName: music.isPreferred ? "star.fill" : "star")
                    .font(.subheadline)
                    .foregroundStyle(music.isPreferred ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            
            Menu {
                Button {
                    onRename()
                } label: {
                    Label("Rename Track", systemImage: "pencil")
                }
                
                Button {
                    onTogglePreferred()
                } label: {
                    Label(music.isPreferred ? "Unmark Preferred" : "Mark as Preferred", systemImage: "star")
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Track", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
