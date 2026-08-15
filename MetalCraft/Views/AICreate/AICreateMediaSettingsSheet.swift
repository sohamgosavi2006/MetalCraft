//
//  AICreateMediaSettingsSheet.swift
//  MetalCraft
//
//  Lightweight media & creative configuration sheet for the AI Create studio.
//  Controls target project selection, individual image/video checkboxes,
//  aspect ratio presets, and soundtrack music preferences.
//

import SwiftUI
import AVFoundation

struct AICreateMediaSettingsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProjectId: UUID?
    @State private var selectedMediaIDs: Set<UUID> = []
    @State private var musicOption: AICreateMusicOption = .auto
    @State private var selectedSoundtrackId: String = "cinematic_emotional_01"
    @State private var aspectRatio: String = "9:16"
    @State private var targetDuration: Double = 15.0
    
    private let aspectRatios = ["9:16", "16:9", "1:1"]
    private let durationOptions: [Double] = [10.0, 15.0, 20.0, 30.0]
    
    private var activeProject: Project? {
        appState.projects.first(where: { $0.id == selectedProjectId }) ?? appState.projects.first
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Section 1: Project Selection
                Section("Target Project") {
                    if appState.projects.isEmpty {
                        Text("No projects available. Create a project in the Projects tab.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        Picker("Select Project", selection: $selectedProjectId) {
                            ForEach(appState.projects) { proj in
                                HStack {
                                    Text(proj.name)
                                    Spacer()
                                    Text("(\(proj.images.count) img, \(proj.videos.count) vid, \(proj.music.count) aud)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .tag(Optional(proj.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                // MARK: - Section 2: Individual Media Selection
                if let project = activeProject {
                    Section {
                        HStack {
                            Text("Media Selection")
                                .font(.headline)
                            Spacer()
                            Button(selectedMediaIDs.count == (project.images.count + project.videos.count) ? "Deselect All" : "Select All") {
                                toggleSelectAll(in: project)
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                        
                        if project.images.isEmpty && project.videos.isEmpty {
                            Text("This project contains no visual media.")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        } else {
                            // Images List
                            ForEach(project.images) { img in
                                mediaRow(
                                    id: img.id,
                                    title: img.name,
                                    type: "Image",
                                    icon: "photo.fill",
                                    color: .blue
                                )
                            }
                            
                            // Videos List
                            ForEach(project.videos) { vid in
                                mediaRow(
                                    id: vid.id,
                                    title: vid.name,
                                    subtitle: vid.videoInfo?.formattedDuration,
                                    type: "Video",
                                    icon: "video.fill",
                                    color: .purple
                                )
                            }
                        }
                    } header: {
                        Text("Eligible Media Assets")
                    } footer: {
                        Text("\(selectedMediaIDs.count) of \(project.images.count + project.videos.count) media items selected for video timeline.")
                    }
                }
                
                // MARK: - Section 3: Music & Soundtrack Preference
                Section("Soundtrack & Music") {
                    Picker("Music Preference", selection: $musicOption) {
                        ForEach(AICreateMusicOption.allCases, id: \.self) { opt in
                            Label(opt.rawValue, systemImage: opt.iconName).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if musicOption == .library {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Choose Soundtrack")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            ForEach(SoundtrackLibrary.shared.tracks) { track in
                                soundtrackRow(track)
                            }
                        }
                        .padding(.vertical, 4)
                    } else if musicOption == .project {
                        if let proj = activeProject, !proj.music.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Project Tracks")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                ForEach(proj.music) { track in
                                    HStack {
                                        Image(systemName: "music.note")
                                            .foregroundStyle(.cyan)
                                        VStack(alignment: .leading) {
                                            Text(track.name)
                                                .font(.subheadline.weight(.medium))
                                            Text("\(track.formattedDuration) • \(track.format.uppercased())")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if track.isPreferred {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(.yellow)
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                        } else {
                            Text("No music tracks uploaded in this project. Using default soundtrack.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if musicOption == .auto {
                        Label("Gemini will intelligently match an appropriate soundtrack based on prompt and visual mood.", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Generated video will contain no background music track.", systemImage: "speaker.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // MARK: - Section 4: Format & Output
                Section("Output Composition") {
                    Picker("Aspect Ratio", selection: $aspectRatio) {
                        Text("9:16 (Vertical Reel)").tag("9:16")
                        Text("16:9 (Widescreen)").tag("16:9")
                        Text("1:1 (Square Feed)").tag("1:1")
                    }
                    
                    Picker("Target Duration", selection: $targetDuration) {
                        ForEach(durationOptions, id: \.self) { d in
                            Text("\(Int(d)) seconds").tag(d)
                        }
                    }
                }
            }
            .navigationTitle("AI Create Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appState.stopAudioPreview()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                        appState.stopAudioPreview()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadInitialSettings()
            }
        }
    }
    
    // MARK: - Subviews
    
    private func mediaRow(
        id: UUID,
        title: String,
        subtitle: String? = nil,
        type: String,
        icon: String,
        color: Color
    ) -> some View {
        Button {
            toggleSelection(id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedMediaIDs.contains(id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedMediaIDs.contains(id) ? .cyan : .secondary)
                    .font(.title3)
                
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text(type.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.15))
                    .foregroundStyle(color)
                    .cornerRadius(4)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func soundtrackRow(_ track: SoundtrackMetadata) -> some View {
        let isSelected = selectedSoundtrackId == track.id
        
        return HStack(spacing: 10) {
            Button {
                selectedSoundtrackId = track.id
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .cyan : .secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text("\(track.category.rawValue) • \(track.mood) • \(track.formattedDuration)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button {
                Task {
                    if let url = try? await SoundtrackLibrary.shared.resolveAudioURL(for: track) {
                        appState.toggleAudioPreview(url: url)
                    }
                }
            } label: {
                Image(systemName: appState.isPlayingAudioPreview ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.cyan)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - State Logic
    
    private func loadInitialSettings() {
        self.selectedProjectId = appState.selectedProjectForAICreate?.id ?? appState.currentProject?.id ?? appState.projects.first?.id
        self.selectedMediaIDs = appState.aiCreateSelectedMediaIDs
        self.musicOption = appState.aiCreateMusicOption
        self.selectedSoundtrackId = appState.aiCreateSelectedSoundtrackId ?? "cinematic_emotional_01"
        self.aspectRatio = appState.aiCreateAspectRatio
        self.targetDuration = appState.aiCreateTargetDuration
        
        if selectedMediaIDs.isEmpty, let proj = activeProject {
            self.selectedMediaIDs = Set(proj.images.map(\.id) + proj.videos.map(\.id))
        }
    }
    
    private func saveSettings() {
        if let proj = activeProject {
            appState.selectedProjectForAICreate = proj
        }
        appState.aiCreateSelectedMediaIDs = selectedMediaIDs
        appState.aiCreateMusicOption = musicOption
        appState.aiCreateSelectedSoundtrackId = selectedSoundtrackId
        appState.aiCreateAspectRatio = aspectRatio
        appState.aiCreateTargetDuration = targetDuration
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedMediaIDs.contains(id) {
            selectedMediaIDs.remove(id)
        } else {
            selectedMediaIDs.insert(id)
        }
    }
    
    private func toggleSelectAll(in project: Project) {
        let allIDs = Set(project.images.map(\.id) + project.videos.map(\.id))
        if selectedMediaIDs.count == allIDs.count {
            selectedMediaIDs.removeAll()
        } else {
            selectedMediaIDs = allIDs
        }
    }
}
