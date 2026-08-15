//
//  AICreateView.swift
//  MetalCraft
//
//  Agentic Media-Production Workspace connecting SwiftUI to Gemini Creative Director,
//  Parallel creative research, multi-scene timeline synthesis, soundtrack audio composition,
//  and real-time Apple Metal GPU video generation from project media.
//

import SwiftUI
import AVKit
import Photos

struct AICreateView: View {
    @Environment(AppState.self) private var appState
    @State private var promptText: String = ""
    @FocusState private var isPromptFocused: Bool
    
    // Media & Project Settings Modal Sheet
    @State private var isShowingMediaSettingsSheet: Bool = false
    
    // Alerts
    @State private var isShowingPhotosSuccessAlert: Bool = false
    @State private var isShowingProjectSuccessAlert: Bool = false
    
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
            VStack(spacing: 0) {
                // 1. Creative Context Strip
                projectMediaHeader
                
                Divider()
                
                // 2. Main Production Workspace Stream
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if appState.agentMessages.isEmpty && !appState.isGeneratingVideo && appState.generatedVideoURL == nil {
                                emptyStateHero
                            } else {
                                ForEach(appState.agentMessages) { msg in
                                    AgentMessageBubble(message: msg) { plan in
                                        handlePlanAction(plan)
                                    }
                                    .id(msg.id)
                                }
                            }
                            
                            // Live Generation Progress Card
                            if appState.isGeneratingVideo, let progress = appState.generationProgress {
                                generationProgressCard(progress)
                                    .id("generation_progress")
                            }
                            
                            // Generated Video Result Card
                            if let videoURL = appState.generatedVideoURL, !appState.isGeneratingVideo {
                                generatedVideoResultCard(videoURL)
                                    .id("video_result")
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
                    .onChange(of: appState.isGeneratingVideo) { _, isGen in
                        if isGen {
                            withAnimation {
                                proxy.scrollTo("generation_progress", anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // 3. Prompt Suggestions Carousel
                suggestionPills
                
                // 4. Interactive Command Input Bar
                inputBar
            }
            .navigationTitle("AI Create")
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
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("AI Create Settings")
                    
                    if !appState.agentMessages.isEmpty || appState.generatedVideoURL != nil {
                        Button {
                            appState.clearAgentConversation()
                        } label: {
                            Image(systemName: "trash")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
    
    // MARK: - Live Generation Progress Card
    
    private func generationProgressCard(_ progress: VideoGenerationProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(progress.stage.rawValue, systemImage: "bolt.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.purple)
                
                Spacer()
                
                Text("\(Int(progress.progress * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            
            ProgressView(value: progress.progress, total: 1.0)
                .tint(.purple)
            
            HStack {
                Text(progress.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if progress.totalFrames > 0 {
                    Text("\(progress.currentFrame)/\(progress.totalFrames) frames")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Generated Video Result Card
    
    private func generatedVideoResultCard(_ videoURL: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Production Ready", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.green)
                
                Spacer()
                
                Text("H.264 • 1080p • 30 FPS • AAC")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            // Video Player
            VideoPlayer(player: AVPlayer(url: videoURL))
                .aspectRatio(9/16, contentMode: .fit)
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Action Controls
            HStack(spacing: 12) {
                Button {
                    Task {
                        let ok = await appState.saveGeneratedVideoToPhotos()
                        if ok {
                            isShowingPhotosSuccessAlert = true
                        }
                    }
                } label: {
                    Label("Save to Photos", systemImage: "square.and.arrow.down")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                
                Button {
                    appState.saveGeneratedVideoToCurrentProject()
                    isShowingProjectSuccessAlert = true
                } label: {
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
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            .padding(.vertical, 8)
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
        .padding(.vertical, 10)
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

