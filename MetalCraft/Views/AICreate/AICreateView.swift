//
//  AICreateView.swift
//  MetalCraft
//
//  Agentic Media-Production Workspace connecting SwiftUI to Gemini Creative Director,
//  Parallel creative research, multi-scene timeline synthesis, soundtrack audio composition,
//  and real-time Apple Metal GPU video generation from project media.
//  Implements idempotent GenerationJob artifact separation, robust video playback preview,
//  and dedicated landscape layout.
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
    @State private var isShowingClearHistoryAlert: Bool = false
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    private var activeProject: Project? {
        appState.selectedProjectForAICreate ?? appState.currentProject ?? appState.projects.first
    }
    
    private var projectSuccessMessage: String {
        let name = activeProject?.name ?? "Project"
        return "Your generated video has been added to '\(name)' under Videos."
    }
    
    var body: some View {
        NavigationStack {
            contentLayout
                .navigationTitle(isLandscape ? "" : "AI Create Studio")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarItems }
                .sheet(isPresented: $isShowingMediaSettingsSheet) {
                    AICreateMediaSettingsSheet()
                }
                .alert("Saved to Photos", isPresented: $isShowingPhotosSuccessAlert) {
                    Button("OK") {}
                } message: {
                    Text("Your AI-generated video reel has been exported directly to your iOS Photos library in 1080p.")
                }
                .alert("Added to Project", isPresented: $isShowingProjectSuccessAlert) {
                    Button("OK") {}
                } message: {
                    Text(projectSuccessMessage)
                }
                .confirmationDialog("Clear Session History?", isPresented: $isShowingClearHistoryAlert) {
                    Button("Clear Conversation & Jobs", role: .destructive) {
                        appState.clearAgentConversation()
                    }
                }
        }
    }
    
    @ViewBuilder
    private var contentLayout: some View {
        if isLandscape {
            landscapeSplitView
        } else {
            portraitLayout
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            projectSelectorButton
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            if !appState.agentMessages.isEmpty || !appState.generationJobs.isEmpty {
                Button {
                    isShowingClearHistoryAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear Session History")
            }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isShowingMediaSettingsSheet = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel("AI Create Settings")
        }
    }
    
    // MARK: - Project Selector Toolbar Button
    
    private var projectSelectorButton: some View {
        Button {
            isShowingMediaSettingsSheet = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "folder.fill")
                    .font(.caption)
                Text(activeProject?.name ?? "Select Project")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(.purple)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.purple.opacity(0.12))
            .clipShape(Capsule())
        }
        .accessibilityLabel("Select Project and Media Settings")
    }
    
    // MARK: - Portrait Layout
    
    private var portraitLayout: some View {
        VStack(spacing: 0) {
            mediaContextStatusBar
            Divider()
            chatAndArtifactStream
            Divider()
            suggestionPills
            inputBar
        }
    }
    
    // MARK: - Dedicated Landscape Split-View Layout
    
    private var landscapeSplitView: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                landscapeMediaHeader
                Divider()
                landscapeSelectedMediaPanel
            }
            .frame(width: 290)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.6))
            
            Divider()
            
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
                    if appState.agentMessages.isEmpty && appState.generationJobs.isEmpty && appState.generatedVideoURL == nil {
                        emptyStateHero
                    } else {
                        messagesList
                        jobsList
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
    
    @ViewBuilder
    private var messagesList: some View {
        ForEach(appState.agentMessages) { msg in
            AgentMessageBubble(message: msg) { plan in
                handlePlanAction(plan)
            }
            .id(msg.id)
        }
    }
    
    @ViewBuilder
    private var jobsList: some View {
        ForEach(appState.generationJobs) { job in
            GenerationJobCard(
                job: job,
                appState: appState,
                onGenerate: {
                    if let proj = activeProject {
                        Task {
                            await appState.executeVideoGeneration(for: job.plan, in: proj)
                        }
                    }
                },
                onSaveToPhotos: {
                    Task {
                        let targetURL = job.outputURL ?? appState.generatedVideoURL
                        let ok = await appState.saveGeneratedVideoToPhotos(url: targetURL)
                        if ok {
                            isShowingPhotosSuccessAlert = true
                        }
                    }
                },
                onAddToProject: {
                    let targetURL = job.outputURL ?? appState.generatedVideoURL
                    appState.saveGeneratedVideoToCurrentProject(url: targetURL)
                    isShowingProjectSuccessAlert = true
                }
            )
            .id(job.id)
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
                    if !project.images.isEmpty {
                        landscapeImagesList(project: project)
                    }
                    if !project.videos.isEmpty {
                        landscapeVideosList(project: project)
                    }
                    if !project.music.isEmpty {
                        landscapeMusicList(project: project)
                    }
                } else {
                    Text("No project selected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                }
            }
            .padding(12)
        }
    }
    
    @ViewBuilder
    private func landscapeImagesList(project: Project) -> some View {
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
    
    @ViewBuilder
    private func landscapeVideosList(project: Project) -> some View {
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
    
    @ViewBuilder
    private func landscapeMusicList(project: Project) -> some View {
        Text("SOUNDTRACKS (\(project.music.count))")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        
        ForEach(project.music) { track in
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundStyle(.cyan)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(track.name)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        if track.isPreferred {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow)
                        }
                    }
                    Text("\(track.formattedDuration) • \(track.format.uppercased())")
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
    
    // MARK: - Media Context Status Bar (Portrait)
    
    private var mediaContextStatusBar: some View {
        HStack(spacing: 12) {
            if let project = activeProject {
                HStack(spacing: 6) {
                    Image(systemName: "photo.stack.fill")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text("\(project.images.count) Photos • \(project.videos.count) Videos")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                    .frame(height: 12)
                
                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                    Text(musicOptionSummaryText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(appState.aiCreateAspectRatio)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(Capsule())
            } else {
                Text("Select a project with photos or videos to start AI generation")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.4))
    }
    
    private var musicOptionSummaryText: String {
        switch appState.aiCreateMusicOption {
        case .noMusic: return "No Music"
        case .auto: return "Auto Match"
        case .project: return activeProject?.preferredMusic?.name ?? "Project Track"
        case .library:
            if let id = appState.aiCreateSelectedSoundtrackId,
               let track = SoundtrackLibrary.shared.track(for: id) {
                return track.title
            }
            return "Library Music"
        }
    }
    
    // MARK: - Empty State Hero
    
    private var emptyStateHero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.25), Color.blue.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.top, 24)
            
            VStack(spacing: 6) {
                Text("Agentic Video Studio")
                    .font(.title3.weight(.bold))
                
                Text("Describe the reel or story you want to create. Gemini and Apple Metal will sequence your project media, apply cinematic GPU shaders, and compose synchronized soundtracks.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }
            
            if let proj = activeProject, (!proj.images.isEmpty || !proj.videos.isEmpty || !proj.music.isEmpty) {
                VStack(spacing: 8) {
                    Text("Selected: '\(proj.name)' (\(proj.images.count) photos, \(proj.videos.count) videos, \(proj.music.count) tracks)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.purple)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Creative Suggestion Pills
    
    private var suggestionPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                suggestionButton("🎬 Create a 15-second cinematic product reel")
                suggestionButton("🌅 Golden hour warmth with slow dissolve")
                suggestionButton("⚡ Fast-paced cyberpunk night aesthetic")
                suggestionButton("✨ Clean minimalist commercial with upbeat music")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private func suggestionButton(_ title: String) -> some View {
        Button {
            promptText = title
            sendPrompt()
        } label: {
            Text(title)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(uiColor: .secondarySystemBackground))
                .foregroundStyle(.primary)
                .clipShape(Capsule())
        }
        .disabled(appState.agentState.isBusy || appState.isGeneratingVideo)
    }
    
    // MARK: - Prompt Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Describe your video reel, pacing, or mood...", text: $promptText, axis: .vertical)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
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
    let appState: AppState
    let onGenerate: () -> Void
    let onSaveToPhotos: () -> Void
    let onAddToProject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerBar
            
            switch job.status {
            case .planning:
                EditPlanPreviewView(plan: job.plan, onApply: { _ in onGenerate() })
            case .preparing, .processing, .rendering, .exporting, .validating:
                renderingProgressBody
            case .completed:
                completedVideoBody
            case .failed:
                failedErrorBody
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
    
    private var headerBar: some View {
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
    }
    
    @ViewBuilder
    private var renderingProgressBody: some View {
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
    }
    
    @ViewBuilder
    private var completedVideoBody: some View {
        if let videoURL = job.outputURL ?? appState.generatedVideoURL {
            VStack(alignment: .leading, spacing: 10) {
                AICreateVideoPreviewPlayer(
                    videoURL: videoURL,
                    thumbnail: appState.generatedVideoThumbnail,
                    aspectRatioString: job.plan.aspectRatio ?? job.plan.output.aspectRatio ?? appState.aiCreateAspectRatio
                )
                
                HStack {
                    Text("1080p • 30 FPS • AAC • \(job.outputFileSizeFormatted ?? "H.264")")
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
    }
    
    @ViewBuilder
    private var failedErrorBody: some View {
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
    
    private var headerColor: Color {
        switch job.status {
        case .planning: return .purple
        case .preparing, .processing, .rendering, .exporting, .validating: return .purple
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Robust Interactive Video Preview Player

struct AICreateVideoPreviewPlayer: View {
    let videoURL: URL
    let thumbnail: UIImage?
    let aspectRatioString: String
    
    @State private var player: AVPlayer? = nil
    @State private var isPlaying: Bool = false
    @State private var isMuted: Bool = false
    @State private var isShowingFullscreen: Bool = false
    @State private var loopObserver: NSObjectProtocol? = nil
    
    private var aspectRatio: CGFloat {
        if aspectRatioString == "16:9" {
            return 16.0 / 9.0
        } else if aspectRatioString == "1:1" {
            return 1.0
        } else {
            return 9.0 / 16.0
        }
    }
    
    var body: some View {
        ZStack {
            videoSurface
            controlsOverlay
        }
        .frame(height: aspectRatioString == "16:9" ? 180 : 320)
        .aspectRatio(aspectRatio, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture {
            togglePlay()
        }
        .task(id: videoURL) {
            setupPlayer()
        }
        .onDisappear {
            teardownPlayer()
        }
        .sheet(isPresented: $isShowingFullscreen) {
            fullscreenSheet
        }
    }
    
    @ViewBuilder
    private var videoSurface: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.black)
        
        if let player {
            VideoPlayer(player: player)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            ProgressView()
                .tint(.white)
        }
    }
    
    @ViewBuilder
    private var controlsOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    isMuted.toggle()
                    player?.isMuted = isMuted
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11, weight: .bold))
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .padding(8)
            }
            
            Spacer()
            
            Button {
                togglePlay()
            } label: {
                ZStack {
                    Circle()
                        .fill(.black.opacity(isPlaying ? 0.001 : 0.6))
                        .frame(width: 54, height: 54)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .opacity(isPlaying ? 0.0 : 1.0)
                }
            }
            
            Spacer()
            
            HStack {
                Label("Apple Metal 1080p", systemImage: "bolt.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                
                Spacer()
                
                Button {
                    isShowingFullscreen = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
            }
            .padding(8)
        }
    }
    
    private var fullscreenSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("AI Video Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isShowingFullscreen = false
                    }
                }
            }
        }
    }
    
    private func setupPlayer() {
        teardownPlayer()
        let newPlayer = AVPlayer(url: videoURL)
        newPlayer.isMuted = isMuted
        newPlayer.actionAtItemEnd = .none
        
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { [weak newPlayer] _ in
            newPlayer?.seek(to: .zero)
            newPlayer?.play()
        }
        
        self.player = newPlayer
        newPlayer.play()
        self.isPlaying = true
    }
    
    private func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
    
    private func teardownPlayer() {
        player?.pause()
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        player = nil
    }
}
