//
//  AICreateView.swift
//  MetalCraft
//
//  Agentic Creative Studio interface connecting SwiftUI to Gemini Creative Director,
//  Parallel creative research, and live GPU EditPlan execution.
//

import SwiftUI

struct AICreateView: View {
    @Environment(AppState.self) private var appState
    @State private var promptText: String = ""
    @State private var isAutoScrollEnabled: Bool = true
    @FocusState private var isPromptFocused: Bool
    
    private let promptSuggestions = [
        "Cinematic Golden Hour",
        "Cyberpunk Teal & Orange",
        "Vintage Film Noir",
        "Product Commercial Pop",
        "Dreamy Soft Glow"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Active Media Context Header
                activeMediaHeader
                
                Divider()
                
                // Conversational Message Stream
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if appState.agentMessages.isEmpty {
                                emptyStateHero
                            } else {
                                ForEach(appState.agentMessages) { msg in
                                    AgentMessageBubble(message: msg) { plan in
                                        applyPlanAndSwitchToEditor(plan)
                                    }
                                    .id(msg.id)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 12)
                    }
                    .onChange(of: appState.agentMessages.count) { _, _ in
                        if let lastId = appState.agentMessages.last?.id {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Prompt Suggestions Carousel
                suggestionPills
                
                // Interactive Input Bar
                inputBar
            }
            .navigationTitle("AI Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !appState.agentMessages.isEmpty {
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
        }
    }
    
    // MARK: - Active Media Header
    
    private var activeMediaHeader: some View {
        HStack(spacing: 10) {
            // Thumbnail
            ZStack {
                if let displayImg = appState.displayImage {
                    Image(uiImage: displayImg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemBackground))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: appState.activeMediaType == .video ? "video.fill" : "photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(mediaTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(mediaSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Agent State Pill
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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
    }
    
    private var mediaTitle: String {
        if let project = appState.currentProject {
            return project.name
        }
        return appState.activeMediaType == .video ? "Current Video" : "Current Image"
    }
    
    private var mediaSubtitle: String {
        if appState.activeMediaType == .video, let info = appState.videoInfo {
            return "\(info.dimensionsText) • \(info.fpsText) • \(info.formattedDuration)"
        } else if let tex = appState.originalTexture {
            return "\(tex.width) × \(tex.height) • Metal Texture"
        } else {
            return "No media loaded"
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
            .padding(.top, 40)
            
            Text("Gemini Creative Director")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            
            Text("Describe your creative intent. Gemini will formulate a structured EditPlan with Parallel research, executed directly on your Apple GPU.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Suggestion Pills
    
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
                    .disabled(appState.agentState.isBusy)
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
                .disabled(appState.agentState.isBusy)
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
        !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !appState.agentState.isBusy
    }
    
    private func sendPrompt() {
        guard canSend else { return }
        let text = promptText
        promptText = ""
        isPromptFocused = false
        
        Task {
            await appState.sendAgentCreativePrompt(text)
        }
    }
    
    private func applyPlanAndSwitchToEditor(_ plan: EditPlan) {
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
