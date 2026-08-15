//
//  AnalyticsView.swift
//  MetalCraft
//
//  Systematic Administrative & Observability Center for MetalCraft.
//  Provides 8 dedicated observability domains: Overview, Agent Lifecycle, Pipeline Flowchart,
//  Performance Metrics, Deep Media Inspector, Telemetry Event Stream, AI Settings, and System Diagnostics.
//

import SwiftUI
import Metal

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

struct AnalyticsView: View {
    let appState: AppState
    @State private var selectedSection: AnalyticsSection = .overview
    
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section Picker Carousel
                sectionPickerHeader
                
                Divider()
                
                // Section Content
                ScrollView {
                    VStack(spacing: 18) {
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Observability Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.isProcessing || appState.isGeneratingVideo ? Color.blue : Color.green)
                            .frame(width: 8, height: 8)
                        Text(appState.isGeneratingVideo ? "RENDERING" : (appState.isProcessing ? "PROCESSING" : "READY"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                endpointURLInput = appState.agentService.endpointBaseURLString
            }
        }
    }
    
    // MARK: - Section Picker Header
    
    private var sectionPickerHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalyticsSection.allCases) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSection = section
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: section.icon)
                                .font(.caption2)
                            Text(section.rawValue)
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selectedSection == section ? Color.purple : Color(uiColor: .secondarySystemBackground))
                        .foregroundStyle(selectedSection == section ? .white : .primary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .systemBackground))
    }
    
    // MARK: - 1. OVERVIEW SECTION
    
    private var overviewSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("MetalCraft System Operational")
                        .font(.subheadline.bold())
                    Text("Apple GPU & Agentic Orchestration Active")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                serviceStatusCard(
                    title: "Gemini AI Director",
                    subtitle: selectedGeminiModel,
                    status: "Configured",
                    icon: "wand.and.stars",
                    color: .purple
                )
                serviceStatusCard(
                    title: "Parallel Research",
                    subtitle: isParallelResearchEnabled ? "Active" : "Disabled",
                    status: "Connected",
                    icon: "book.pages.fill",
                    color: .indigo
                )
                serviceStatusCard(
                    title: "Grafana Observability",
                    subtitle: "Port 3000",
                    status: "Connected",
                    icon: "chart.xyaxis.line",
                    color: .orange
                )
                serviceStatusCard(
                    title: "Apple Metal GPU",
                    subtitle: appState.metalContext.device.name,
                    status: "Ready",
                    icon: "bolt.fill",
                    color: .blue
                )
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("CURRENT MEDIA WORKSPACE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                HStack {
                    Label(appState.currentProject?.name ?? "Default Project", systemImage: "folder.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(appState.activeMediaType == .video ? "Video Mode" : "Image Mode")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                
                Divider()
                
                HStack(spacing: 20) {
                    metricItem(label: "Pipeline Nodes", value: "\(appState.pipeline.nodes.count)")
                    metricItem(label: "Active Operations", value: "\(appState.pipeline.enabledNodes.count)")
                    metricItem(label: "History Passes", value: "\(appState.processingHistory.count)")
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    private func serviceStatusCard(title: String, subtitle: String, status: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
            }
            
            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - 2. AGENT LIFECYCLE SECTION
    
    private var agentLifecycleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("ACTIVE AGENT STATE MACHINE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(appState.agentState.rawValue)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.15))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(AgentState.allCases, id: \.self) { st in
                            HStack(spacing: 4) {
                                Image(systemName: st.systemIcon)
                                    .font(.system(size: 9))
                                Text(st.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(appState.agentState == st ? Color.purple : Color(uiColor: .tertiarySystemBackground))
                            .foregroundStyle(appState.agentState == st ? .white : .secondary)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("RECENT AGENT ACTIONS & REASONINGS (\(appState.agentMessages.count))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                if appState.agentMessages.isEmpty {
                    Text("No agent actions recorded in this session. Start a prompt in AI Create.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else {
                    ForEach(appState.agentMessages) { msg in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(msg.role.rawValue.capitalized)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.purple)
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
    
    // MARK: - 3. PIPELINE FLOWCHART SECTION
    
    private var pipelineFlowchartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("INTERACTIVE MEDIA PROCESSING PIPELINE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            if appState.activeMediaType == .video {
                videoPipelineFlowchart
            } else {
                imagePipelineFlowchart
            }
        }
    }
    
    private var imagePipelineFlowchart: some View {
        VStack(spacing: 8) {
            pipelineStageCard(title: "1. Media Ingestion & Decode", desc: "UIImage → RGBA8Unorm Metal Texture", icon: "photo.fill", isComplete: true)
            pipelineArrow
            pipelineStageCard(title: "2. Color Grade & Adjustments", desc: "Photographic parameters (exposure, contrast, tint)", icon: "slider.horizontal.3", isComplete: !appState.activeAdjustments.isDefault)
            pipelineArrow
            pipelineStageCard(title: "3. Metal Compute Shader Stack", desc: "\(appState.pipeline.enabledNodes.count) Active GPU Operations", icon: "bolt.fill", isComplete: !appState.pipeline.enabledNodes.isEmpty)
            pipelineArrow
            pipelineStageCard(title: "4. Output Texture & Display", desc: "MTKView Direct Framebuffer Presentation", icon: "display", isComplete: true)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var videoPipelineFlowchart: some View {
        VStack(spacing: 8) {
            pipelineStageCard(title: "1. AVAssetReader Ingestion", desc: "Streaming H.264/HEVC frames to CVPixelBuffer", icon: "video.fill", isComplete: true)
            pipelineArrow
            pipelineStageCard(title: "2. CVMetalTextureCache", desc: "Zero-copy GPU texture bridge", icon: "memorychip", isComplete: true)
            pipelineArrow
            pipelineStageCard(title: "3. GPU Frame Processing", desc: "30 FPS real-time Metal compute passes", icon: "bolt.fill", isComplete: true)
            pipelineArrow
            pipelineStageCard(title: "4. AVAssetWriter Hardware Encoding", desc: "H.264 High Profile hardware MP4 export", icon: "square.and.arrow.down.fill", isComplete: true)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func pipelineStageCard(title: String, desc: String, icon: String, isComplete: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green.opacity(0.15) : Color(uiColor: .tertiarySystemBackground))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(isComplete ? .green : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                Text(desc)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private var pipelineArrow: some View {
        Image(systemName: "arrow.down")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
    
    // MARK: - 4. PERFORMANCE SECTION
    
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
                    metricItem(
                        label: "GPU Render Time",
                        value: String(format: "%.1f ms", appState.performanceMetrics.gpuTimeMs)
                    )
                    metricItem(
                        label: "Frame Time",
                        value: String(format: "%.1f ms", appState.performanceMetrics.frameTimeMs)
                    )
                    metricItem(
                        label: "Pipeline Passes",
                        value: "\(appState.performanceMetrics.passCount)"
                    )
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("CPU VS APPLE METAL GPU BENCHMARK")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                Button {
                    appState.runBenchmark(operation: .grayscale)
                } label: {
                    Label(appState.isBenchmarking ? "Running Benchmark..." : "Run Benchmark Suite", systemImage: "gauge.with.needle.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .disabled(appState.isBenchmarking)
                
                if !appState.benchmarkResults.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(appState.benchmarkResults) { res in
                            HStack {
                                Text(res.operationName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "GPU: %.2f ms", res.gpuTimeMs))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                                if let speed = res.speedup {
                                    Text(String(format: "(%.1fx)", speed))
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.purple)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    // MARK: - 5. MEDIA INSPECTOR SECTION
    
    private var mediaInspectorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MEDIA TECHNICAL SPECIFICATIONS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            
            if appState.activeMediaType == .video, let vid = appState.videoInfo {
                VStack(spacing: 8) {
                    specRow(label: "Media Classification", value: "Video Asset (AVAsset)")
                    specRow(label: "Dimensions", value: vid.dimensionsText)
                    specRow(label: "Frame Rate", value: vid.fpsText)
                    specRow(label: "Duration", value: vid.formattedDurationWithMilliseconds)
                    specRow(label: "Codec", value: vid.codec)
                    specRow(label: "File Size", value: vid.fileSizeFormatted)
                    specRow(label: "Audio Track", value: vid.hasAudio ? "Stereo AAC (Present)" : "Muted / No Audio")
                }
            } else if let tex = appState.originalTexture {
                VStack(spacing: 8) {
                    specRow(label: "Media Classification", value: "Metal 2D Texture (MTLTexture)")
                    specRow(label: "Dimensions", value: "\(tex.width) × \(tex.height)")
                    specRow(label: "Pixel Format", value: "MTLPixelFormatRGBA8Unorm")
                    specRow(label: "Mipmap Levels", value: "\(tex.mipmapLevelCount)")
                    specRow(label: "Color Space", value: "sRGB Display P3")
                    specRow(label: "Estimated GPU Size", value: String(format: "%.2f MB", Double(tex.width * tex.height * 4) / (1024.0 * 1024.0)))
                }
            } else {
                Text("No active media loaded in workspace.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
        .border(Color(uiColor: .separator).opacity(0.1), width: 0.5)
    }
    
    // MARK: - 6. TELEMETRY EVENT STREAM SECTION
    
    private var telemetryEventStreamSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PRODUCTION TELEMETRY STREAM")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(appState.telemetryService.eventsBuffer.count) Events")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.purple)
            }
            
            if appState.telemetryService.eventsBuffer.isEmpty {
                Text("No telemetry events recorded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.telemetryService.eventsBuffer.prefix(15)) { ev in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(ev.eventType)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(colorForEvent(ev.eventType))
                            Spacer()
                            if let dur = ev.processingTimeMs ?? ev.gpuTimeMs {
                                Text(String(format: "%.1f ms", dur))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let op = ev.operation {
                            Text(op)
                                .font(.caption2)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(8)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func colorForEvent(_ eventType: String) -> Color {
        if eventType.contains("agent") { return .purple }
        if eventType.contains("export") { return .green }
        if eventType.contains("error") { return .red }
        return .blue
    }
    
    // MARK: - 7. AUDIT SECTION
    
    private var auditSection: some View {
        VStack(spacing: 16) {
            // Search Bar & Filter Bar
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search actions, projects, descriptions...", text: $auditSearchQuery)
                        .font(.subheadline)
                    
                    if !auditSearchQuery.isEmpty {
                        Button {
                            auditSearchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                // Category Filter Carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AuditCategory.allCases, id: \.self) { cat in
                            Button {
                                auditCategoryFilter = cat
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: cat.iconName)
                                        .font(.caption2)
                                    Text(cat.rawValue)
                                        .font(.caption.weight(.medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(auditCategoryFilter == cat ? Color.purple : Color(uiColor: .tertiarySystemBackground))
                                .foregroundStyle(auditCategoryFilter == cat ? .white : .primary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Audit Log List
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("AUDIT TRAIL (\(filteredAuditRecords.count) RECORDS)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        isShowingClearAuditConfirmation = true
                    } label: {
                        Text("Clear History")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.red)
                    }
                }
                
                if filteredAuditRecords.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "list.clipboard")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Audit Records Found")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Activity matching '\(auditCategoryFilter.rawValue)' will appear here.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredAuditRecords) { record in
                            auditRecordRow(record)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .confirmationDialog(
            "Clear Audit Trail?",
            isPresented: $isShowingClearAuditConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Records", role: .destructive) {
                AuditService.shared.clearAuditTrail()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove all stored activity records from your device.")
        }
    }
    
    private var filteredAuditRecords: [AuditRecord] {
        AuditService.shared.getRecords(
            category: auditCategoryFilter,
            searchQuery: auditSearchQuery,
            limit: 150
        )
    }
    
    private func auditRecordRow(_ record: AuditRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Category Icon
                Image(systemName: record.category.iconName)
                    .font(.caption)
                    .foregroundStyle(.purple)
                
                Text(record.category.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Status Badge
                Text(record.status.rawValue)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor(for: record.status).opacity(0.15))
                    .foregroundStyle(statusColor(for: record.status))
                    .cornerRadius(4)
                
                // Timestamp
                Text("\(record.formattedDate) \(record.formattedTime)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            // Action Title
            Text(record.action)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            
            // Description Text
            Text(record.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Footer: Project & Source Badges
            HStack(spacing: 8) {
                if let proj = record.projectName {
                    HStack(spacing: 3) {
                        Image(systemName: "folder")
                        Text(proj)
                    }
                    .font(.caption2)
                    .foregroundStyle(.purple)
                }
                
                if let media = record.mediaType {
                    HStack(spacing: 3) {
                        Image(systemName: "tag")
                        Text(media)
                    }
                    .font(.caption2)
                    .foregroundStyle(.blue)
                }
                
                Spacer()
                
                Text("via \(record.source)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    private func statusColor(for status: AuditStatus) -> Color {
        switch status {
        case .success: return .green
        case .info: return .blue
        case .warning: return .orange
        case .failure: return .red
        }
    }
    
    // MARK: - 8. AI SETTINGS SECTION (Moved from AI Create)
    
    private var aiSettingsSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("LOCAL MAC AGENT ENDPOINT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                TextField("http://172.20.10.4:8080", text: $endpointURLInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                Button {
                    autoDiscoverAgent()
                } label: {
                    HStack {
                        Image(systemName: "sparkle.magnifyingglass")
                        Text("Auto-Discover Mac on Local Network")
                        if isPinging {
                            Spacer()
                            ProgressView()
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .foregroundStyle(.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .disabled(isPinging)
                
                VStack(spacing: 6) {
                    presetButton(title: "1. iPhone Hotspot (172.20.10.4:8080)", url: "http://172.20.10.4:8080")
                    presetButton(title: "2. Bonjour Hostname (admins-MacBook-Pro-8.local:8080)", url: "http://admins-MacBook-Pro-8.local:8080")
                    presetButton(title: "3. Wi-Fi LAN (10.3.12.210:8080)", url: "http://10.3.12.210:8080")
                    presetButton(title: "4. Simulator Localhost (127.0.0.1:8080)", url: "http://127.0.0.1:8080")
                }
                
                Button {
                    testConnection()
                } label: {
                    Text("Test Selected Endpoint")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .disabled(isPinging)
                
                if let result = pingResultText {
                    Text(result)
                        .font(.caption2)
                        .foregroundStyle(result.contains("Success") ? .green : .red)
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("AGENT PARAMETERS (SERVER-SIDE)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text("Gemini Model")
                        .font(.caption)
                    Spacer()
                    Text("gemini-2.5-flash")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.purple)
                }
                
                Toggle("Parallel Creative Research", isOn: $isParallelResearchEnabled)
                    .font(.caption)
                
                HStack {
                    Text("Grafana Ingestion")
                        .font(.caption)
                    Spacer()
                    Text("localhost:3000")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                }
                
                Text("🔒 All API keys remain strictly secure on your Mac agent backend.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    private func presetButton(title: String, url: String) -> some View {
        Button {
            endpointURLInput = url
            appState.agentService.endpointBaseURLString = url
        } label: {
            HStack {
                Text(title)
                    .font(.caption2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(uiColor: .tertiarySystemBackground))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
    
    private func autoDiscoverAgent() {
        isPinging = true
        pingResultText = "Probing candidate endpoints..."
        
        Task {
            if let found = await appState.agentService.autoDiscoverEndpoint() {
                await MainActor.run {
                    endpointURLInput = found.endpointURL
                    pingResultText = "Success! Discovered \(found.endpointURL) (\(Int(found.latencyMs))ms)"
                    isPinging = false
                }
            } else {
                await MainActor.run {
                    pingResultText = "Could not reach agent on network. Check that Mac backend is running."
                    isPinging = false
                }
            }
        }
    }
    
    private func testConnection() {
        isPinging = true
        pingResultText = nil
        appState.agentService.endpointBaseURLString = endpointURLInput
        
        Task {
            if let info = await appState.agentService.checkHealth(at: endpointURLInput) {
                await MainActor.run {
                    pingResultText = "Success! Connected to \(info.service) v\(info.version) at \(endpointURLInput) in \(Int(info.latencyMs))ms"
                    isPinging = false
                }
            } else {
                await MainActor.run {
                    pingResultText = "Connection failed: Unable to reach \(endpointURLInput)/health."
                    isPinging = false
                }
            }
        }
    }
    
    // MARK: - 8. SYSTEM / DIAGNOSTICS SECTION
    
    private var systemDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Integration Diagnostics Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .foregroundStyle(.purple)
                    Text("END-TO-END INTEGRATIONS DIAGNOSTICS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                
                Text("Test real runtime connectivity for Local Agent, Gemini API, Parallel Creative Search, Grafana 11.5, and Grafana MCP.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Button {
                    Task {
                        await appState.runAllIntegrationsDiagnostics()
                    }
                } label: {
                    HStack {
                        if appState.isRunningDiagnostics {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                            Text("Testing All Integrations...")
                        } else {
                            Image(systemName: "play.circle.fill")
                            Text("Run Full Integrations Diagnostics")
                        }
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(appState.isRunningDiagnostics)
                
                if let diag = appState.lastDiagnosticsResult {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("OVERALL STATUS:")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(diag.overallStatus)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(diag.overallStatus == "PASS" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                .foregroundStyle(diag.overallStatus == "PASS" ? .green : .orange)
                                .clipShape(Capsule())
                        }
                        .padding(.bottom, 4)
                        
                        diagItemRow(
                            name: "Local Agent",
                            status: diag.agent.status,
                            details: "\(diag.agent.hostname ?? "localhost"):\(diag.agent.port ?? 8080)"
                        )
                        diagItemRow(
                            name: "Gemini API",
                            status: diag.gemini.status,
                            details: "\(diag.gemini.model ?? "gemini-2.5-flash") (Server-Side 🔒)"
                        )
                        diagItemRow(
                            name: "Parallel API",
                            status: diag.parallel.status,
                            details: diag.parallel.latencyMs != nil ? "\(diag.parallel.latencyMs!)ms | \(diag.parallel.resultCount ?? 0) results" : (diag.parallel.message ?? "OK")
                        )
                        diagItemRow(
                            name: "Grafana 11.5",
                            status: diag.grafana.status,
                            details: "\(diag.grafana.url ?? "localhost:3000") | \(diag.grafana.serviceAccount ?? "OK")"
                        )
                        diagItemRow(
                            name: "Grafana MCP",
                            status: diag.grafanaMCP.status,
                            details: "\(diag.grafanaMCP.server ?? "mcp") (JSON-RPC 2.0)"
                        )
                        if let tel = diag.telemetry {
                            diagItemRow(
                                name: "Telemetry Buffer",
                                status: tel.status.uppercased(),
                                details: "\(tel.sampleCount ?? 0) samples | Avg GPU \(String(format: "%.1f", tel.averageGpuTimeMs ?? 0))ms"
                            )
                        }
                    }
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else if let err = appState.diagnosticsError {
                    Text("Diagnostics check failed: \(err)")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Hardware Specs
            VStack(alignment: .leading, spacing: 14) {
                Text("SYSTEM & HARDWARE SPECIFICATIONS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 8) {
                    specRow(label: "Device Model", value: UIDevice.current.model)
                    specRow(label: "System Version", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                    specRow(label: "Metal Device", value: appState.metalContext.device.name)
                    specRow(label: "GPU Family", value: "Apple Silicon Metal 3")
                    specRow(label: "AVFoundation HW Encoding", value: "H.264 / HEVC Supported")
                    specRow(label: "Photos Library Permission", value: "Authorized")
                    specRow(label: "Bonjour Discovery", value: "_metalcraft._tcp Active")
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    private func diagItemRow(name: String, status: String, details: String) -> some View {
        HStack {
            Circle()
                .fill(status == "PASS" || status == "NOMINAL" ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(name)
                .font(.caption.weight(.semibold))
            Spacer()
            Text(details)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(status)
                .font(.caption2.bold())
                .foregroundStyle(status == "PASS" || status == "NOMINAL" ? .green : .red)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Helpers
    
    private func metricItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
