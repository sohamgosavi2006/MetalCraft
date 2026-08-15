//
//  AICreateView.swift
//  MetalCraft
//
//  Agentic Media-Production Workspace connecting SwiftUI to Gemini Creative Director,
//  Parallel creative research, multi-scene timeline synthesis, and real-time
//  Apple Metal GPU video generation from project media.
//

import SwiftUI
import AVKit
import Photos

struct AICreateView: View {
    @Environment(AppState.self) private var appState
    @State private var promptText: String = ""
    @FocusState private var isPromptFocused: Bool
    
    // Project Selection
    @State private var isProjectPickerPresented: Bool = false
    @State private var selectedProject: Project? = nil
    
    // Video Playback & Fullscreen Preview
    @State private var isShowingVideoPlayer: Bool = false
    @State private var isShowingPhotosSuccessAlert: Bool = false
    @State private var isShowingProjectSuccessAlert: Bool = false
    
    private let promptSuggestions = [
        "Create a 15-second cinematic product reel",
        "Fast-paced social media highlight reel",
        "Warm golden hour vintage montage",
        "Moody neo-noir cyberpunk showcase",
        "High-contrast black and white gallery tape"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. Project & Media Asset Strip Header
                projectMediaHeader
                
                Divider()
                
                // 2. Main Production Workspace Stream
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 18) {
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
                        .padding(.horizontal, 14)
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
                
                ToolbarItem(placement: .topBarTrailing) {
                    if !appState.agentMessages.isEmpty || appState.generatedVideoURL != nil {
                        Button {
                            appState.clearAgentConversation()
                        } label: {
                            Image(systemName: "trash")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onAppear {
                if selectedProject == nil {
                    selectedProject = appState.currentProject ?? appState.projects.first
                }
            }
            .alert("Saved to Photos!", isPresented: $isShowingPhotosSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your generated cinematic video has been exported directly to your Photo Library.")
            }
            .alert("Added to Project!", isPresented: $isShowingProjectSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The generated video was saved into '\(selectedProject?.name ?? "Project")' as a new video asset.")
            }
        }
    }
    
    // MARK: - Project & Media Header
    
    private var projectMediaHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                // Project Icon & Name
                Image(systemName: "folder.fill.badge.gearshape")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedProject?.name ?? "No Project Selected")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text("\(selectedProject?.images.count ?? 0) Images • \(selectedProject?.videos.count ?? 0) Videos")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Agent Lifecycle State Badge
                HStack(spacing: 5) {
                    if appState.agentState.isBusy {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: appState.agentState.systemIcon)
                            .font(.caption2)
                    }
                    
                    Text(appState.agentState.rawValue)
                        .font(.caption2.weight(.medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statePillBackground)
                .foregroundStyle(statePillForeground)
                .clipShape(Capsule())
            }
            
            // Horizontal Asset Strip
            if let proj = selectedProject, (!proj.images.isEmpty || !proj.videos.isEmpty) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(proj.images) { img in
                            assetThumbnail(title: img.name, isVideo: false)
                        }
                        ForEach(proj.videos) { vid in
                            assetThumbnail(title: vid.name, isVideo: true, duration: vid.videoInfo?.formattedDuration)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
    }
    
    private func assetThumbnail(title: String, isVideo: Bool, duration: String? = nil) -> some View {
        HStack(spacing: 5) {
            Image(systemName: isVideo ? "video.fill" : "photo.fill")
                .font(.system(size: 10))
                .foregroundStyle(isVideo ? .orange : .purple)
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            
            if let dur = duration {
                Text(dur)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    private var projectSelectorMenu: some View {
        Menu {
            ForEach(appState.projects) { proj in
                Button {
                    selectedProject = proj
                    appState.selectedProjectForAICreate = proj
                } label: {
                    HStack {
                        Text(proj.name)
                        if selectedProject?.id == proj.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedProject?.name ?? "Select Project")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(.purple)
        }
    }
    
    private var statePillBackground: Color {
        if appState.agentState.isBusy {
            return Color.purple.opacity(0.15)
        } else if appState.agentState == .failed {
            return Color.red.opacity(0.15)
        } else {
            return Color(uiColor: .tertiarySystemBackground)
        }
    }
    
    private var statePillForeground: Color {
        if appState.agentState.isBusy {
            return .purple
        } else if appState.agentState == .failed {
            return .red
        } else {
            return .secondary
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
            .padding(.top, 30)
            
            Text("Agentic Video Studio")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            
            Text("Select a project containing images and videos, then describe your creative vision. Gemini will formulate a multi-scene timeline rendered live on your Apple GPU.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }
    
    // MARK: - Live Generation Progress Card
    
    private func generationProgressCard(_ progress: VideoGenerationProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Final Video Ready", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.green)
                
                Spacer()
                
                Text("H.264 • 1080p • 30 FPS")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            // Video Player
            VideoPlayer(player: AVPlayer(url: videoURL))
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Action Controls: Save to Photos & Add to Project
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
    
    // MARK: - Prompt Suggestion Pills
    
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
            TextField("Describe video intent (e.g. 15s cinematic reel)...", text: $promptText, axis: .vertical)
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
        
        let proj = selectedProject ?? appState.currentProject ?? appState.projects.first
        
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
            // Multi-scene Video Generation
            if let proj = selectedProject ?? appState.currentProject ?? appState.projects.first {
                Task {
                    await appState.executeVideoGeneration(for: plan, in: proj)
                }
            }
        } else {
            // Single-Image Pipeline Execution
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
