//
//  AICreateView.swift
//  MetalCraft
//
//  Agentic Media-Production Workspace connecting SwiftUI to Gemini Creative Director,
//  Parallel creative research, multi-scene timeline synthesis, soundtrack audio composition,
//  and real-time Apple Metal GPU video generation from project media.
//  Implements idempotent GenerationJob artifact separation and dedicated landscape layout.
//

import SwiftUI
import AVKit
import Photos

struct AICreateView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @State private var promptText: String = ""
    @FocusState private var isPromptFocused: Bool
    
    // Media & Project Settings Modal Sheet
    @State private var isShowingMediaSettingsSheet: Bool = false
    
    // Alerts
    @State private var isShowingPhotosSuccessAlert: Bool = false
    @State private var isShowingProjectSuccessAlert: Bool = false
    
    var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    private let promptSuggestions = [
        "Create a 15-second cinematic product reel with emotional music",
        "Fast-paced social media highlight reel with upbeat music",
        "Warm golden hour vintage montage with acoustic soundtrack",
        "Moody neo-noir cyberpunk showcase with electronic pulse",
        "High-contrast black and white gallery tape with ambient music"
    ]
    
    private var activeProject: Project? {
        appState.selectedProjectForAICreate ?? appState.currentProject ?? appState.projects.first
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLandscape {
                    landscapeAICreateLayout
                } else {
                    portraitAICreateLayout
                }
            }
            .navigationTitle(isLandscape ? "" : "AI Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    projectSelectorMenu
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isShowingMediaSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: isLandscape ? 16 : 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(minWidth: isLandscape ? 36 : 28, minHeight: isLandscape ? 36 : 28)
                    }
                    .accessibilityLabel("AI Create Settings")
                    
                    if !appState.agentMessages.isEmpty || !appState.generationJobs.isEmpty {
                        Button {
                            appState.clearAgentConversation()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: isLandscape ? 16 : 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: isLandscape ? 36 : 28, minHeight: isLandscape ? 36 : 28)
                        }
                        .accessibilityLabel("Clear Conversation")
                    }
                }
            }
            .sheet(isPresented: $isShowingMediaSettingsSheet) {
                AICreateMediaSettingsSheet()
            }
            .alert("Saved to Photos!", isPresented: $isShowingPhotosSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your generated cinematic video with soundtrack has been exported directly to your Photo Library.")
            }
            .alert("Added to Project!", isPresented: $isShowingProjectSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The generated video was saved into '\(activeProject?.name ?? "Project")' as a new video asset.")
            }
        }
    }
    
    // MARK: - Portrait Layout
    
    private var portraitAICreateLayout: some View {
        VStack(spacing: 0) {
            // 1. Creative Context Strip
            projectMediaHeader
            
            Divider()
            
            // 2. Main Production Workspace Stream
            chatAndArtifactStream
            
            Divider()
            
            // 3. Prompt Suggestions Carousel
            suggestionPills
            
            // 4. Interactive Command Input Bar
            inputBar
        }
    }
    
    // MARK: - Dedicated Landscape Split-View Layout
    
    private var landscapeAICreateLayout: some View {
        HStack(spacing: 0) {
            // Left Panel: Selected Media & Context
            VStack(spacing: 0) {
                landscapeMediaHeader
                
                Divider()
                
                landscapeSelectedMediaPanel
            }
            .frame(width: 290)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
            
            Divider()
            
            // Right Panel: Chat Stream + Input Bar
            VStack(spacing: 0) {
                chatAndArtifactStream
                
                Divider()
                
                suggestionPills
                
                inputBar
            }
        }
    }
    
    // MARK: - Chat & Artifact Stream
    
    private var chatAndArtifactStream: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if appState.agentMessages.isEmpty && appState.generationJobs.isEmpty {
                        emptyStateHero
                    } else {
                        // Render Chat Messages
                        ForEach(appState.agentMessages) { msg in
                            AgentMessageBubble(message: msg) { plan in
                                handlePlanAction(plan)
                            }
                            .id(msg.id)
                        }
                        
                        // Render Generation Artifacts (Idempotent: Single evolving card per job)
                        ForEach(appState.generationJobs) { job in
                            GenerationJobCard(
                                job: job,
                                onGenerate: {
                                    if let proj = activeProject {
                                        Task {
                                            await appState.executeVideoGeneration(for: job.plan, in: proj)
                                        }
                                    }
                                },
                                onSaveToPhotos: {
                                    Task {
                                        let ok = await appState.saveGeneratedVideoToPhotos()
                                        if ok {
                                            isShowingPhotosSuccessAlert = true
                                        }
                                    }
                                },
                                onAddToProject: {
                                    appState.saveGeneratedVideoToCurrentProject()
                                    isShowingProjectSuccessAlert = true
                                }
                            )
                            .id(job.id)
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
            }
            .onChange(of: appState.agentMessages.count) { _, _ in
                if let lastId = appState.agentMessages.last?.id {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: appState.generationJobs.count) { _, _ in
                if let lastJob = appState.generationJobs.last?.id {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastJob, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Landscape Selected Media Panel
    
    private var landscapeMediaHeader: some View {
        HStack {
            Label("Project Assets", systemImage: "photo.on.rectangle.angled")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button {
                isShowingMediaSettingsSheet = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(uiColor: .tertiarySystemBackground))
    }
    
    private var landscapeSelectedMediaPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let project = activeProject {
                    // Images List
                    if !project.images.isEmpty {
                        Text("IMAGES (\(project.images.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        
                        ForEach(project.images) { img in
                            HStack(spacing: 8) {
                                Image(systemName: "photo.fill")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(img.name)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(1)
                                    Text("\(img.imageInfo?.dimensionsText ?? "PNG")")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                            }
                            .padding(6)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    
                    // Videos List
                    if !project.videos.isEmpty {
                        Text("VIDEOS (\(project.videos.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        
                        ForEach(project.videos) { vid in
                            HStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                    .font(.caption)
                                    .foregroundStyle(.purple)
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(vid.name)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(1)
                                    Text("\(String(format: "%.1f", vid.videoInfo?.duration ?? 0))s • \(vid.videoInfo?.dimensionsText ?? "1080p")")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                            }
                            .padding(6)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    
                    // Music List
                    if !project.music.isEmpty {
                        Text("MUSIC TRACKS (\(project.music.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        
                        ForEach(project.music) { mus in
                            HStack(spacing: 8) {
                                Image(systemName: "music.note")
                                    .font(.caption)
                                    .foregroundStyle(.cyan)
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 4) {
                                        Text(mus.name)
                                            .font(.caption.weight(.medium))
                                            .lineLimit(1)
                                        if mus.isPreferred {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 8))
                                                .foregroundStyle(.yellow)
                                        }
                                    }
                                    Text("\(mus.formattedDuration) • \(mus.format.uppercased())")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                            }
                            .padding(6)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                } else {
                    Text("No project selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .padding(12)
        }
    }
    
    // MARK: - Project & Media Header Context
    
    private var projectMediaHeader: some View {
        Button {
            isShowingMediaSettingsSheet = true
        } label: {
            HStack(spacing: 12) {
                if let project = activeProject {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.purple)
                        .font(.subheadline)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 8) {
                            Text("\(project.images.count) img • \(project.videos.count) vid")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 3) {
                                Image(systemName: appState.aiCreateMusicOption == .noMusic ? "speaker.slash" : "music.note")
                                Text(musicStatusText)
                            }
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(appState.aiCreateMusicOption == .noMusic ? Color.secondary : Color.cyan)
                        }
                    }
                } else {
                    Label("Select Project & Media", systemImage: "folder.badge.plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "sliders.horizontal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.6))
        }
        .buttonStyle(.plain)
    }
    
    private var musicStatusText: String {
        switch appState.aiCreateMusicOption {
        case .auto: return "Auto Music"
        case .project: return "Project Track"
        case .library:
            if let tr = SoundtrackLibrary.shared.track(for: appState.aiCreateSelectedSoundtrackId ?? "") {
                return tr.title
            }
            return "Library Music"
        case .noMusic: return "No Music"
        }
    }
    
    private var projectSelectorMenu: some View {
        Menu {
            ForEach(appState.projects) { proj in
                Button {
                    appState.selectedProjectForAICreate = proj
                } label: {
                    HStack {
                        Text(proj.name)
                        if activeProject?.id == proj.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(activeProject?.name ?? "Select Project")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(.purple)
        }
    }
    
    // MARK: - Empty State Hero
    
    private var emptyStateHero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.purple)
            }
            .padding(.top, 24)
            
            Text("Agentic Media Studio")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            
            Text("Describe your creative intent. Gemini will formulate a multi-scene timeline, match a licensed soundtrack, and compose GPU video with AVFoundation audio.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Prompt Suggestions Carousel
    
    private var suggestionPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(promptSuggestions, id: \.self) { suggestion in
                    Button {
                        promptText = suggestion
                        sendPrompt()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text(suggestion)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                    }
                    .disabled(appState.agentState.isBusy || appState.isGeneratingVideo)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Describe creative intent...", text: $promptText, axis: .vertical)
                .focused($isPromptFocused)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .disabled(appState.agentState.isBusy || appState.isGeneratingVideo)
                .onSubmit {
                    sendPrompt()
                }
            
            Button {
                sendPrompt()
            } label: {
                ZStack {
                    Circle()
                        .fill(canSend ? Color.purple : Color.secondary.opacity(0.3))
                        .frame(width: 36, height: 36)
                    
                    if appState.agentState.isBusy {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }
    
    private var canSend: Bool {
        !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !appState.agentState.isBusy && !appState.isGeneratingVideo
    }
    
    private func sendPrompt() {
        guard canSend else { return }
        let text = promptText
        promptText = ""
        isPromptFocused = false
        
        let proj = activeProject
        
        Task {
            if let validProj = proj {
                await appState.sendAgentProjectCreativePrompt(text, project: validProj)
            } else {
                await appState.sendAgentCreativePrompt(text)
            }
        }
    }
    
    private func handlePlanAction(_ plan: EditPlan) {
        if !plan.scenes.isEmpty || plan.mediaType == .video {
            if let proj = activeProject {
                Task {
                    await appState.executeVideoGeneration(for: plan, in: proj)
                }
            }
        } else {
            do {
                try appState.applyEditPlan(plan)
                withAnimation {
                    appState.selectedTab = .editor
                }
            } catch {
                appState.errorMessage = error.localizedDescription
                appState.showError = true
            }
        }
    }
}

// MARK: - Stateful Generation Job Artifact Card

struct GenerationJobCard: View {
    let job: GenerationJob
    let onGenerate: () -> Void
    let onSaveToPhotos: () -> Void
    let onAddToProject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Bar with Status & Artifact ID
            HStack {
                Label(job.status.displayName, systemImage: job.status.iconName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(headerColor)
                
                Spacer()
                
                Text(job.artifactId)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(Capsule())
            }
            
            // Dynamic Body based on Lifecycle
            switch job.status {
            case .planning:
                EditPlanPreviewView(plan: job.plan, onApply: { _ in onGenerate() })
                
            case .preparing, .processing, .rendering, .exporting, .validating:
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(job.progressMessage)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(Int(job.progress * 100))%")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    ProgressView(value: job.progress, total: 1.0)
                        .tint(.purple)
                    
                    HStack {
                        Label("Metal GPU Active", systemImage: "cpu.fill")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                        
                        Spacer()
                        
                        if job.totalFrames > 0 {
                            Text("\(job.currentFrame) / \(job.totalFrames) frames")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
                
            case .completed:
                if let videoURL = job.outputURL {
                    VStack(alignment: .leading, spacing: 10) {
                        VideoPlayer(player: AVPlayer(url: videoURL))
                            .aspectRatio(9/16, contentMode: .fit)
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
                        HStack {
                            Text("1080p • 30 FPS • AAC • \(job.outputFileSizeFormatted ?? "")")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let dur = job.renderDurationSec {
                                Text("Render: \(String(format: "%.1f", dur))s")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: onSaveToPhotos) {
                                Label("Save to Photos", systemImage: "square.and.arrow.down")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.purple)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            
                            Button(action: onAddToProject) {
                                Label("Add to Project", systemImage: "folder.badge.plus")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(uiColor: .tertiarySystemBackground))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }
                
            case .failed:
                VStack(alignment: .leading, spacing: 8) {
                    Text(job.error ?? "An unexpected generation error occurred.")
                        .font(.caption)
                        .foregroundStyle(.red)
                    
                    Button(action: onGenerate) {
                        Label("Retry Metal Generation", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(headerColor.opacity(0.25), lineWidth: 1)
        )
    }
    
    private var headerColor: Color {
        switch job.status {
        case .planning: return .purple
        case .preparing, .processing, .rendering, .exporting, .validating: return .purple
        case .completed: return .green
        case .failed: return .red
        }
    }
}
