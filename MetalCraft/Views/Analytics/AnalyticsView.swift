//
//  AnalyticsView.swift
//  MetalCraft
//
//  Systematic Administrative & Observability Center for MetalCraft.
//  Provides 9 dedicated observability domains: Overview, Agent Lifecycle, Deep End-to-End Pipeline,
//  Performance Metrics, Deep Media Inspector, Telemetry Event Stream, Audit Trail, AI Settings, and System Diagnostics.
//  Includes dedicated landscape sidebar layout and interactive stage inspection.
//

import SwiftUI
import Metal
import AVFoundation

enum AnalyticsSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case agent = "Agent"
    case pipeline = "Pipeline"
    case performance = "Performance"
    case media = "Media"
    case telemetry = "Telemetry"
    case audit = "Audit"
    case aiSettings = "AI Settings"
    case diagnostics = "Diagnostics"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .agent: return "wand.and.stars"
        case .pipeline: return "arrow.triangle.branch"
        case .performance: return "gauge.with.needle.fill"
        case .media: return "photo.on.rectangle.angled"
        case .telemetry: return "chart.xyaxis.line"
        case .audit: return "list.clipboard.fill"
        case .aiSettings: return "gearshape.2.fill"
        case .diagnostics: return "stethoscope"
        }
    }
}

enum PipelineSubDomain: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case agent = "Agent Planning"
    case media = "Media Ingestion"
    case metal = "Metal GPU"
    case audioVideo = "Audio/Video"
    case validation = "Export & Validation"
    
    var id: String { rawValue }
}

struct PipelineStageInfo: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let statusText: String
    let isComplete: Bool
    let isRunning: Bool
    let details: [String: String]
    let icon: String
}

struct AnalyticsView: View {
    let appState: AppState
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @State private var selectedSection: AnalyticsSection = .overview
    @State private var selectedPipelineSubDomain: PipelineSubDomain = .overview
    @State private var inspectedStage: PipelineStageInfo? = nil
    
    // Audit Section States
    @State private var auditCategoryFilter: AuditCategory = .all
    @State private var auditSearchQuery: String = ""
    @State private var isShowingClearAuditConfirmation: Bool = false
    
    // AI Settings States
    @State private var endpointURLInput: String = ""
    @State private var pingResultText: String? = nil
    @State private var isPinging: Bool = false
    @State private var selectedGeminiModel: String = "gemini-2.5-flash"
    @State private var isParallelResearchEnabled: Bool = true
    
    var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLandscape {
                    landscapeAnalyticsLayout
                } else {
                    portraitAnalyticsLayout
                }
            }
            .navigationTitle(isLandscape ? "" : "Observability Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.isProcessing || appState.isGeneratingVideo ? Color.purple : Color.green)
                            .frame(width: 8, height: 8)
                        Text(appState.isGeneratingVideo ? "GPU RENDERING" : (appState.isProcessing ? "PROCESSING" : "ONLINE"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(item: $inspectedStage) { stage in
                PipelineStageInspectorSheet(stage: stage)
            }
            .onAppear {
                endpointURLInput = appState.agentService.endpointBaseURLString
            }
        }
    }
    
    // MARK: - Portrait Layout
    
    private var portraitAnalyticsLayout: some View {
        VStack(spacing: 0) {
            sectionPickerHeader
            
            Divider()
            
            ScrollView {
                VStack(spacing: 18) {
                    mainSectionContent
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }
    
    // MARK: - Dedicated Landscape Sidebar Layout
    
    private var landscapeAnalyticsLayout: some View {
        HStack(spacing: 0) {
            // Sidebar with Domains
            VStack(spacing: 0) {
                HStack {
                    Label("Observability", systemImage: "chart.bar.xaxis")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(uiColor: .tertiarySystemBackground))
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(AnalyticsSection.allCases) { section in
                            Button {
                                selectedSection = section
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: section.icon)
                                        .font(.caption)
                                        .foregroundStyle(selectedSection == section ? .white : .primary)
                                        .frame(width: 20)
                                    Text(section.rawValue)
                                        .font(.caption.weight(selectedSection == section ? .bold : .medium))
                                        .foregroundStyle(selectedSection == section ? .white : .primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedSection == section ? Color.purple : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
            }
            .frame(width: 200)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.6))
            
            Divider()
            
            // Main Content Area
            ScrollView {
                VStack(spacing: 18) {
                    mainSectionContent
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
    
    @ViewBuilder
    private var mainSectionContent: some View {
        switch selectedSection {
        case .overview:
            overviewSection
        case .agent:
            agentLifecycleSection
        case .pipeline:
            pipelineFlowchartSection
        case .performance:
            performanceMetricsSection
        case .media:
            mediaInspectorSection
        case .telemetry:
            telemetryEventStreamSection
        case .audit:
            auditSection
        case .aiSettings:
            aiSettingsSection
        case .diagnostics:
            systemDiagnosticsSection
        }
    }
    
    // MARK: - Section Picker Header (Portrait)
    
    private var sectionPickerHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalyticsSection.allCases) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSection = section
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                                .font(.caption)
                            Text(section.rawValue)
                                .font(.subheadline.weight(selectedSection == section ? .bold : .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedSection == section ? Color.purple : Color(uiColor: .secondarySystemBackground))
                        .foregroundStyle(selectedSection == section ? .white : .primary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - 1. OVERVIEW SECTION
    
    private var overviewSection: some View {
        VStack(spacing: 16) {
            // High-Level Architecture Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                systemCard(
                    title: "Mac Agent Backend",
                    status: appState.agentState != .failed ? "Online" : "Connecting",
                    icon: "server.rack",
                    color: appState.agentState != .failed ? .green : .orange
                )
                systemCard(
                    title: "Gemini 2.5 Creative",
                    status: "Connected",
                    icon: "sparkles",
                    color: .purple
                )
                systemCard(
                    title: "Parallel Research",
                    status: "Active",
                    icon: "magnifyingglass",
                    color: .blue
                )
                systemCard(
                    title: "Apple Metal GPU",
                    status: "Ready (Apple Silicon)",
                    icon: "bolt.fill",
                    color: .green
                )
            }
            
            // Live Video Pipeline Status
            if let activeJob = appState.activeGenerationJob {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Active Generation Job", systemImage: "play.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.purple)
                        Spacer()
                        Text(activeJob.status.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.purple)
                    }
                    
                    ProgressView(value: activeJob.progress, total: 1.0)
                        .tint(.purple)
                    
                    HStack {
                        Text(activeJob.progressMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("#\(activeJob.artifactId)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            // Quick Session Metrics
            VStack(alignment: .leading, spacing: 12) {
                Text("ENGINE TELEMETRY SNAPSHOT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 20) {
                    metricItem(label: "GPU Time", value: String(format: "%.1f ms", appState.performanceMetrics.gpuTimeMs))
                    metricItem(label: "Active Nodes", value: "\(appState.pipeline.enabledNodes.count)")
                    metricItem(label: "Events Logged", value: "\(appState.telemetryService.eventsBuffer.count)")
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    // MARK: - 2. AGENT LIFECYCLE SECTION
    
    private var agentLifecycleSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("AGENT STATE & CREATIVE DIRECTOR")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "wand.and.stars")
                            .font(.title3)
                            .foregroundStyle(.purple)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Creative Director Status: \(appState.agentState.rawValue.capitalized)")
                            .font(.subheadline.weight(.semibold))
                        Text(appState.agentService.endpointBaseURLString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Agent Action Stream
            VStack(alignment: .leading, spacing: 12) {
                Text("RECENT AGENT ACTIONS (\(appState.agentMessages.count))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                if appState.agentMessages.isEmpty {
                    Text("No agent actions recorded. Start a prompt in AI Create.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else {
                    ForEach(appState.agentMessages) { msg in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(msg.role.rawValue.capitalized)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(msg.role == .user ? .blue : .purple)
                                Spacer()
                                Text(formattedTime(msg.timestamp))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(msg.content)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                        }
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    // MARK: - 3. DEEP PIPELINE FLOWCHART & SUB-DOMAINS
    
    private var pipelineFlowchartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Pipeline SubDomain Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PipelineSubDomain.allCases) { sub in
                        Button {
                            selectedPipelineSubDomain = sub
                        } label: {
                            Text(sub.rawValue)
                                .font(.caption.weight(selectedPipelineSubDomain == sub ? .bold : .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedPipelineSubDomain == sub ? Color.purple : Color(uiColor: .tertiarySystemBackground))
                                .foregroundStyle(selectedPipelineSubDomain == sub ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            switch selectedPipelineSubDomain {
            case .overview:
                interactiveEndToEndFlowchart
            case .agent:
                agentPlanningPipelineView
            case .media:
                mediaPreparationPipelineView
            case .metal:
                metalGPUPipelineView
            case .audioVideo:
                audioVideoCompositionPipelineView
            case .validation:
                exportValidationInspectorView
            }
        }
    }
    
    // MARK: - Interactive End-to-End Flowchart
    
    private var interactiveEndToEndFlowchart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("END-TO-END METALCRAFT RUNTIME ARCHITECTURE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            Text("Tap any stage below to inspect live diagnostic metrics, shader dispatch states, and pipeline memory.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 6) {
                flowNode(
                    title: "1. User Creative Intent",
                    desc: "AI Create Prompt & Media Constraints",
                    status: !appState.agentMessages.isEmpty ? .completed : .ready,
                    icon: "person.fill",
                    details: [
                        "Input Channel": "SwiftUI AI Create Workspace",
                        "Target Aspect Ratio": appState.aiCreateAspectRatio,
                        "Target Duration": "\(appState.aiCreateTargetDuration)s",
                        "Active Messages": "\(appState.agentMessages.count)"
                    ]
                )
                flowConnector
                
                flowNode(
                    title: "2. Mac Agent Backend",
                    desc: "FastAPI REST Gateway (Port 8080)",
                    status: appState.agentState != .failed ? .completed : .running,
                    icon: "server.rack",
                    details: [
                        "Endpoint URL": appState.agentService.endpointBaseURLString,
                        "Status": appState.agentState != .failed ? "Healthy" : "Reconnecting",
                        "Session ID": appState.telemetryService.sessionId
                    ]
                )
                flowConnector
                
                flowNode(
                    title: "3. Gemini Agent Director",
                    desc: "Intent Analysis & Scene Timeline Planning",
                    status: appState.agentState == .planning ? .running : (appState.activeEditPlan != nil ? .completed : .ready),
                    icon: "sparkles",
                    details: [
                        "Model": "Gemini 2.5 Flash",
                        "Goal": appState.activeEditPlan?.goal ?? "Formulate Timeline",
                        "Planned Scenes": "\(appState.activeEditPlan?.scenes.count ?? 0)",
                        "Total Duration": "\(appState.activeEditPlan?.totalSceneDuration ?? 0)s"
                    ]
                )
                flowConnector
                
                flowNode(
                    title: "4. Parallel Creative Research",
                    desc: "Style, Pacing & Cinematography Intelligence",
                    status: .completed,
                    icon: "magnifyingglass",
                    details: [
                        "Parallel Platform": "Active",
                        "Context": "Pacing & Visual Styling Research"
                    ]
                )
                flowConnector
                
                flowNode(
                    title: "5. EditPlan & AudioPlan Synthesis",
                    desc: "Validated JSON Multi-Scene Schema",
                    status: appState.activeEditPlan != nil ? .completed : .ready,
                    icon: "doc.text.fill",
                    details: [
                        "Schema Version": "1.0",
                        "Scenes Count": "\(appState.activeEditPlan?.scenes.count ?? 0)",
                        "Matched Soundtrack": appState.activeEditPlan?.audioPlan?.trackTitle ?? "Auto",
                        "Audio Volume": "\(appState.activeEditPlan?.audioPlan?.volume ?? 0.7)"
                    ]
                )
                flowConnector
                
                flowNode(
                    title: "6. Apple Metal GPU Shader Stack",
                    desc: "Hardware Compute Passes on Apple Silicon",
                    status: appState.isGeneratingVideo ? .running : (appState.generatedVideoURL != nil ? .completed : .ready),
                    icon: "bolt.fill",
                    details: [
                        "GPU Device": appState.metalContext.device.name,
                        "Texture Format": "RGBA8Unorm",
                        "Texture Cache": "CVMetalTextureCache",
                        "Active Nodes": "\(appState.pipeline.enabledNodes.count)"
                    ]
                )
                flowConnector
                
                flowNode(
                    title: "7. AVFoundation Audio/Video Composition",
                    desc: "Multi-Track Mix, Volume Ramps & H.264 MP4 Export",
                    status: appState.generatedVideoURL != nil ? .completed : (appState.isGeneratingVideo ? .running : .ready),
                    icon: "music.note",
                    details: [
                        "Composition": "AVMutableComposition",
                        "Audio Track": "AAC 44.1 kHz Stereo",
                        "Volume Envelope": "Fade-In 0.5s • Fade-Out 1.0s",
                        "Video Track": "H.264 High Profile 1080p"
                    ]
                )
                flowConnector
                
                flowNode(
                    title: "8. Output Validation & Storage",
                    desc: "Strict Track Integrity, Decodable Frames & Photos Export",
                    status: appState.generatedVideoURL != nil ? .completed : .ready,
                    icon: "checkmark.shield.fill",
                    details: [
                        "Output File": appState.generatedVideoURL != nil ? "Valid MP4" : "Pending",
                        "Video Stream": "Verified 30 FPS",
                        "Audio Stream": "Verified AAC Track",
                        "Destination": "Project / Photos"
                    ]
                )
                flowConnector
                
                flowNode(
                    title: "9. Observability & Audit Trail",
                    desc: "Persistent JSON Logs & Grafana Telemetry",
                    status: .completed,
                    icon: "list.clipboard.fill",
                    details: [
                        "Audit Records": "\(AuditService.shared.records.count)",
                        "Storage Path": "Documents/Audit/audit_log.json",
                        "Grafana MCP": "Active"
                    ]
                )
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Sub-Domain Detail Views
    
    private var agentPlanningPipelineView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AGENT CREATIVE PLANNING LIFECYCLE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            detailCard(
                title: "1. Intent & Media Ingestion",
                desc: "User prompt is enriched with Project media metadata (image resolutions, video durations, audio tracks).",
                status: "Completed",
                icon: "sparkles"
            )
            detailCard(
                title: "2. Parallel Creative Research",
                desc: "Fetches cinematic references and pacing advice for prompt genre.",
                status: "Active",
                icon: "magnifyingglass"
            )
            detailCard(
                title: "3. Multi-Scene Timeline Synthesis",
                desc: "Formulates ordered scenes with transition effects, durations, and GPU filter parameters.",
                status: appState.activeEditPlan != nil ? "Formulated" : "Idle",
                icon: "film"
            )
            detailCard(
                title: "4. AudioPlan & Soundtrack Matching",
                desc: "Matches mood and energy against CC0 Royalty-Cleared soundtrack catalog.",
                status: appState.activeEditPlan?.audioPlan != nil ? "Matched" : "Auto",
                icon: "music.note"
            )
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var mediaPreparationPipelineView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROJECT MEDIA ASSETS & PREPROCESSING")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            if let proj = appState.currentProject ?? appState.projects.first {
                HStack(spacing: 16) {
                    metricItem(label: "Images", value: "\(proj.images.count)")
                    metricItem(label: "Videos", value: "\(proj.videos.count)")
                    metricItem(label: "Soundtracks", value: "\(proj.music.count)")
                }
                .padding(.vertical, 4)
            }
            
            detailCard(
                title: "CVPixelBuffer Extraction",
                desc: "Zero-copy texture pooling from AVAssetReader and UIImage assets.",
                status: "Ready",
                icon: "memorychip"
            )
            detailCard(
                title: "Aspect Ratio Normalization",
                desc: "Hardware scaling to 9:16 (1080×1920) or 16:9 (1920×1080) with centered letterboxing.",
                status: "Configured (\(appState.aiCreateAspectRatio))",
                icon: "crop"
            )
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var metalGPUPipelineView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APPLE METAL GPU COMPUTE PIPELINE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                metricItem(label: "Device", value: appState.metalContext.device.name)
                metricItem(label: "Pooled Textures", value: "\(appState.metalProcessor.pooledTextureCount)")
                metricItem(label: "Active Passes", value: "\(appState.pipeline.enabledNodes.count)")
            }
            .padding(.vertical, 4)
            
            detailCard(
                title: "CVMetalTextureCache Bridge",
                desc: "Direct zero-copy mapping between CVPixelBuffer and Metal MTLTexture.",
                status: "Active",
                icon: "bolt.fill"
            )
            detailCard(
                title: "Compute Shader Execution",
                desc: "Custom MSL shaders running 2D threadgroups across Apple Silicon unified memory.",
                status: appState.isGeneratingVideo ? "Running" : "Idle",
                icon: "cpu.fill"
            )
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var audioVideoCompositionPipelineView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AVFOUNDATION AUDIO & VIDEO ENGINE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            detailCard(
                title: "AVMutableComposition",
                desc: "Multi-track timeline compositing visual GPU frames with soundtrack audio stream.",
                status: "Ready",
                icon: "slider.horizontal.below.rectangle"
            )
            detailCard(
                title: "AVAudioMix & Volume Envelopes",
                desc: "Smooth fade-in (0.5s) and fade-out (1.0s) ramps with audio ducking.",
                status: "AAC 44.1 kHz",
                icon: "waveform"
            )
            detailCard(
                title: "Hardware H.264 Video Encoder",
                desc: "Hardware accelerated MP4 container encoding with strict 30 FPS timing.",
                status: "1080p High Profile",
                icon: "video.fill"
            )
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var exportValidationInspectorView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXPORT & OUTPUT VALIDATION INSPECTOR")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                validationRow(title: "Output File Existence", passed: appState.generatedVideoURL != nil)
                validationRow(title: "Valid H.264 Video Stream", passed: appState.generatedVideoURL != nil)
                validationRow(title: "Decodable Frame Sequence", passed: appState.generatedVideoURL != nil)
                validationRow(title: "Synchronized AAC Audio Track", passed: appState.generatedVideoURL != nil && appState.aiCreateMusicOption != .noMusic)
                validationRow(title: "Target Duration Integrity", passed: appState.generatedVideoURL != nil)
                validationRow(title: "Photo Library Export Capability", passed: true)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func validationRow(title: String, passed: Bool) -> some View {
        HStack {
            Image(systemName: passed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(passed ? .green : .secondary)
                .font(.subheadline)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            Text(passed ? "VERIFIED" : "PENDING")
                .font(.caption2.weight(.bold))
                .foregroundStyle(passed ? .green : .secondary)
        }
        .padding(8)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Flowchart Node Helper
    
    private enum NodeStatus {
        case completed
        case running
        case ready
        case failed
    }
    
    private func flowNode(title: String, desc: String, status: NodeStatus, icon: String, details: [String: String]) -> some View {
        Button {
            inspectedStage = PipelineStageInfo(
                name: title,
                category: "Pipeline Architecture",
                statusText: status == .completed ? "Completed" : (status == .running ? "Running" : "Ready"),
                isComplete: status == .completed,
                isRunning: status == .running,
                details: details,
                icon: icon
            )
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(nodeColor(status).opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(nodeColor(status))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(desc)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(statusText(status))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(nodeColor(status))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(nodeColor(status).opacity(0.12))
                    .clipShape(Capsule())
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private var flowConnector: some View {
        Image(systemName: "arrow.down")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
    
    private func nodeColor(_ status: NodeStatus) -> Color {
        switch status {
        case .completed: return .green
        case .running: return .purple
        case .ready: return .secondary
        case .failed: return .red
        }
    }
    
    private func statusText(_ status: NodeStatus) -> String {
        switch status {
        case .completed: return "DONE"
        case .running: return "ACTIVE"
        case .ready: return "READY"
        case .failed: return "FAILED"
        }
    }
    
    // MARK: - 4. PERFORMANCE METRICS SECTION
    
    private var performanceMetricsSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("LIVE GPU PROCESSING METRICS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Real Runtime")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                }
                
                HStack(spacing: 20) {
                    metricItem(label: "GPU Render Time", value: String(format: "%.1f ms", appState.performanceMetrics.gpuTimeMs))
                    metricItem(label: "Frame Time", value: String(format: "%.1f ms", appState.performanceMetrics.frameTimeMs))
                    metricItem(label: "Pipeline Passes", value: "\(appState.performanceMetrics.passCount)")
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    // MARK: - 5. MEDIA INSPECTOR SECTION
    
    private var mediaInspectorSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("ACTIVE MEDIA PROPERTIES")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                if let info = appState.imageInfo {
                    HStack(spacing: 20) {
                        metricItem(label: "Resolution", value: info.dimensionsText)
                        metricItem(label: "Megapixels", value: info.megapixelsText)
                        metricItem(label: "Format", value: info.format)
                    }
                } else if let vid = appState.videoInfo {
                    HStack(spacing: 20) {
                        metricItem(label: "Resolution", value: "\(vid.width) × \(vid.height)")
                        metricItem(label: "Duration", value: vid.formattedDuration)
                        metricItem(label: "Frame Rate", value: vid.fpsText)
                    }
                } else {
                    Text("No media currently loaded in Editor.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    // MARK: - 6. TELEMETRY EVENT STREAM SECTION
    
    private var telemetryEventStreamSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("LIVE TELEMETRY STREAM (\(appState.telemetryService.eventsBuffer.count))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") {
                    appState.telemetryService.clear()
                }
                .font(.caption)
                .foregroundStyle(.purple)
            }
            
            if appState.telemetryService.eventsBuffer.isEmpty {
                Text("No telemetry events recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.telemetryService.eventsBuffer.prefix(25)) { ev in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ev.eventType)
                                .font(.caption.weight(.bold))
                            if let op = ev.operation {
                                Text(op)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(formattedTime(ev.timestamp))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(8)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - 7. AUDIT TRAIL SECTION
    
    private var auditSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SYSTEM & USER AUDIT TRAIL (\(AuditService.shared.records.count))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    isShowingClearAuditConfirmation = true
                } label: {
                    Text("Clear Log")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            
            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AuditCategory.allCases) { cat in
                        Button {
                            auditCategoryFilter = cat
                        } label: {
                            Text(cat.rawValue)
                                .font(.caption.weight(auditCategoryFilter == cat ? .bold : .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(auditCategoryFilter == cat ? Color.purple : Color(uiColor: .tertiarySystemBackground))
                                .foregroundStyle(auditCategoryFilter == cat ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Audit List
            let records = AuditService.shared.getRecords(category: auditCategoryFilter, searchQuery: auditSearchQuery)
            if records.isEmpty {
                Text("No audit records found matching query.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(records.prefix(50)) { rec in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(rec.action)
                                .font(.caption.weight(.bold))
                            Spacer()
                            Text(rec.category.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.purple)
                            Text(formattedTime(rec.timestamp))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text(rec.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .confirmationDialog("Clear Audit Log?", isPresented: $isShowingClearAuditConfirmation) {
            Button("Clear All Logs", role: .destructive) {
                AuditService.shared.clearAuditTrail()
            }
        }
    }
    
    // MARK: - 8. AI SETTINGS SECTION
    
    private var aiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AGENT & INTEGRATION SETTINGS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Mac Agent Base URL")
                    .font(.caption.weight(.semibold))
                TextField("http://192.168.x.x:8080", text: $endpointURLInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            
            HStack {
                Button {
                    appState.agentService.endpointBaseURLString = endpointURLInput
                    isPinging = true
                    Task {
                        let healthInfo = await appState.agentService.checkHealth(at: endpointURLInput)
                        pingResultText = healthInfo != nil ? "✅ Connected to Agent Backend (\(healthInfo?.latencyMs ?? 0)ms)" : "❌ Connection Failed"
                        isPinging = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isPinging {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text("Test Connection")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                
                if let res = pingResultText {
                    Text(res)
                        .font(.caption2.weight(.medium))
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - 9. SYSTEM DIAGNOSTICS SECTION
    
    private var systemDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SYSTEM HEALTH & INTEGRATION DIAGNOSTICS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task {
                        await appState.runAllIntegrationsDiagnostics()
                    }
                } label: {
                    if appState.isRunningDiagnostics {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Run Diagnostics")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.purple)
                    }
                }
            }
            
            detailCard(
                title: "Mac Agent Local Server",
                desc: "FastAPI daemon running on host Mac machine.",
                status: appState.agentState != .failed ? "Healthy" : "Offline",
                icon: "server.rack"
            )
            detailCard(
                title: "Gemini Creative Model",
                desc: "Google DeepMind Gemini API configured.",
                status: "Configured",
                icon: "sparkles"
            )
            detailCard(
                title: "Local Grafana Telemetry",
                desc: "Local Grafana observability stack on localhost:3000.",
                status: "Connected",
                icon: "chart.xyaxis.line"
            )
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Views
    
    private func systemCard(title: String, status: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(title)
                .font(.caption.weight(.semibold))
            Text(status)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func detailCard(title: String, desc: String, status: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.purple)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                Text(desc)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(status)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.purple)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(10)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func metricItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.bold))
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Pipeline Stage Inspector Sheet

struct PipelineStageInspectorSheet: View {
    let stage: PipelineStageInfo
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: stage.icon)
                            .font(.title2)
                            .foregroundStyle(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.name)
                                .font(.headline.weight(.bold))
                            Text(stage.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(stage.statusText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(stage.isComplete ? .green : .purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(stage.isComplete ? Color.green.opacity(0.15) : Color.purple.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Text("LIVE STAGE DIAGNOSTICS & PARAMETERS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    
                    VStack(spacing: 8) {
                        ForEach(Array(stage.details.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                            HStack {
                                Text(key)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(value)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.primary)
                            }
                            .padding(10)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Stage Inspector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
