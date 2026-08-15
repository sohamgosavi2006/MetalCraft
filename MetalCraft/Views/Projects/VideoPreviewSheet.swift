//
//  VideoPreviewSheet.swift
//  MetalCraft
//
//  Native video inspection and playback sheet.
//  Presents AVFoundation video player, technical metadata, Save to Photos,
//  Share Sheet, and direct "Open in Editor" action.
//

import SwiftUI
import AVKit
import Photos

struct VideoPreviewSheet: View {
    @Bindable var appState: AppState
    let project: Project
    let video: ProjectVideo
    @Environment(\.dismiss) private var dismiss
    
    @State private var player: AVPlayer? = nil
    @State private var videoURL: URL? = nil
    @State private var isSavedToPhotos: Bool = false
    @State private var saveMessage: String? = nil
    @State private var showingShareSheet: Bool = false
    @State private var isSaving: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // AVFoundation Video Player Area
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if let player {
                        VideoPlayer(player: player)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .padding(.horizontal)
                
                // Metadata Information
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(video.name)
                                .font(.title3.weight(.bold))
                            
                            Text(project.name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if let info = video.videoInfo {
                            Text(info.formattedDuration)
                                .font(.headline.monospacedDigit())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    
                    if let info = video.videoInfo {
                        HStack {
                            Text(info.dimensionsText)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(info.fpsText)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(info.hasAudio ? "Audio: Stereo" : "No Audio")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(info.fileSizeFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 20)
                
                // Action Buttons Bar
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        // Save to Photos Button
                        Button {
                            saveToPhotos()
                        } label: {
                            HStack(spacing: 6) {
                                if isSaving {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: isSavedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down")
                                }
                                Text(isSavedToPhotos ? "Saved" : "Save to Photos")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(isSavedToPhotos ? .green : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(videoURL == nil || isSaving)
                        .accessibilityLabel("Save Video to Camera Roll")
                        
                        // Native Share Button
                        Button {
                            showingShareSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(videoURL == nil)
                        .accessibilityLabel("Share Video")
                    }
                    
                    // Open in Editor Action Button
                    Button {
                        player?.pause()
                        appState.openProject(project, video: video)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Open in Editor")
                                .fontWeight(.semibold)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel("Open Video in Editor")
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Video Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        player?.pause()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = videoURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Photos", isPresented: Binding(get: { saveMessage != nil }, set: { _ in saveMessage = nil })) {
                Button("OK") {}
            } message: {
                Text(saveMessage ?? "")
            }
            .task {
                if let url = appState.projectManager.loadOriginalVideoURL(projectId: project.id, video: video) {
                    self.videoURL = url
                    self.player = AVPlayer(url: url)
                }
            }
        }
    }
    
    private func saveToPhotos() {
        guard let url = videoURL else { return }
        isSaving = true
        Task {
            do {
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                guard status == .authorized || status == .limited else {
                    await MainActor.run {
                        isSaving = false
                        saveMessage = "Photos access is required to save this video."
                    }
                    return
                }
                
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }
                
                await MainActor.run {
                    isSaving = false
                    isSavedToPhotos = true
                    saveMessage = "Video successfully saved to your Photos library."
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveMessage = "Failed to save video: \(error.localizedDescription)"
                }
            }
        }
    }
}
