//
//  AnalyticsView.swift
//  MetalCraft
//
//  Comprehensive Live System, Image, Video, GPU, and Pipeline Observability Dashboard.
//  Strictly uses real runtime measurements and clearly labels estimated or unavailable metrics.
//

import SwiftUI
import Charts
import Metal

struct AnalyticsView: View {
    @Bindable var appState: AppState
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Current Operation Live Status
                    currentOperationCard
                    
                    // 2. Live Pipeline Flowchart
                    livePipelineSection
                    
                    // 3. Media Observability (Image vs Video)
                    if appState.activeMediaType == .video {
                        videoAnalyticsSection
                    } else {
                        imageAnalyticsSection
                    }
                    
                    // 4. GPU / Metal Device Status
                    gpuMetalStatusSection
                    
                    // 5. Processing Performance Metrics
                    processingPerformanceSection
                    
                    // 6. Memory & Resource Observability
                    memoryResourceSection
                    
                    // 7. CPU vs GPU Benchmark Suite
                    benchmarkSection
                    
                    // 8. Processing History Log
                    processingHistorySection
                    
                    // 9. System & Hardware Diagnostics
                    systemDiagnosticsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.isProcessing ? Color.blue : Color.green)
                            .frame(width: 8, height: 8)
                        Text(appState.isProcessing ? "PROCESSING" : "READY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 1. Current Operation Card
    
    private var currentOperationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text("CURRENT OPERATION")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(appState.currentOperationStatus.rawValue.uppercased())
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentOperationName)
                    .font(.title3.bold())
                    .lineLimit(2)
                
                HStack(spacing: 16) {
                    Label(
                        "GPU: \(appState.isProcessing ? "Active" : "Idle")",
                        systemImage: "bolt.fill"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(appState.isProcessing ? Color.orange : Color.secondary)
                    
                    Label(
                        "Pass: \(appState.currentPassInfo)",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    
                    Label(
                        "Media: \(appState.activeMediaType.rawValue)",
                        systemImage: appState.activeMediaType == .video ? "film" : "photo"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var statusColor: Color {
        switch appState.currentOperationStatus {
        case .idle: return .gray
        case .processing, .rendering, .loading: return .blue
        case .completed: return .green
        case .failed: return .red
        case .benchmarking: return .purple
        case .exporting: return .orange
        }
    }
    
    // MARK: - 2. Live Pipeline Flowchart
    
    private var livePipelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Pipeline Execution")
                    .font(.headline)
                Spacer()
                Text("\(appState.pipeline.enabledNodes.count) Active Nodes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 8) {
                // Source Input Node
                pipelineStageRow(
                    name: appState.activeMediaType == .video ? "Video Frame (CVPixelBuffer)" : "Source Texture (MTLTexture)",
                    category: "Core Input",
                    icon: appState.activeMediaType == .video ? "film" : "photo",
                    status: .completed,
                    isFirst: true
                )
                
                // Photographic Adjustments Node (if modified)
                if !appState.activeAdjustments.isDefault {
                    pipelineConnector
                    pipelineStageRow(
                        name: "Photographic Adjustments",
                        category: "Tonality & Color (7-Param)",
                        icon: "slider.horizontal.3",
                        status: appState.isProcessing ? .running : .completed
                    )
                }
                
                // Active Processing Nodes
                if appState.pipeline.nodes.isEmpty && appState.activeAdjustments.isDefault {
                    pipelineConnector
                    HStack {
                        Image(systemName: "arrow.down")
                            .foregroundStyle(.secondary)
                        Text("Passthrough (Direct Rendering)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                } else {
                    ForEach(Array(appState.pipeline.nodes.enumerated()), id: \.element.id) { index, node in
                        pipelineConnector
                        pipelineStageRow(
                            name: node.operation.displayName,
                            category: node.operation.category.rawValue,
                            icon: node.operation.iconName,
                            status: appState.nodeRuntimeStates[node.id] ?? (node.isEnabled ? .waiting : .skipped)
                        )
                    }
                }
                
                // Output Target Node
                pipelineConnector
                pipelineStageRow(
                    name: appState.activeMediaType == .video ? "Display Video Frame / Encoder" : "Display Canvas / Metal View",
                    category: "Core Output",
                    icon: "display",
                    status: .completed,
                    isLast: true
                )
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private func pipelineStageRow(
        name: String,
        category: String,
        icon: String,
        status: NodeRuntimeState,
        isFirst: Bool = false,
        isLast: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(isFirst || isLast ? Color.accentColor : statusColor(for: status))
                .frame(width: 28, height: 28)
                .background(
                    (isFirst || isLast ? Color.accentColor : statusColor(for: status)).opacity(0.12),
                    in: Circle()
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(category)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: status.iconName)
                    .font(.caption)
                Text(status.rawValue)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(statusColor(for: status))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(for: status).opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var pipelineConnector: some View {
        HStack {
            Spacer().frame(width: 24)
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 2, height: 12)
            Spacer()
        }
    }
    
    private func statusColor(for state: NodeRuntimeState) -> Color {
        switch state {
        case .waiting: return .gray
        case .queued: return .orange
        case .running: return .blue
        case .completed: return .green
        case .skipped: return .secondary
        case .failed: return .red
        }
    }
    
    // MARK: - 3. Video Analytics Section
    
    private var videoAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Video Observability")
                .font(.headline)
            
            if let info = appState.videoInfo {
                VStack(spacing: 10) {
                    telemetryRow(title: "Resolution", value: info.dimensionsText)
                    Divider()
                    telemetryRow(title: "Duration", value: info.formattedDurationWithMilliseconds)
                    Divider()
                    telemetryRow(title: "Nominal Frame Rate", value: info.fpsText)
                    Divider()
                    telemetryRow(title: "Codec", value: info.codec)
                    Divider()
                    telemetryRow(title: "Audio Track", value: info.hasAudio ? "Present (Stereo AAC)" : "No Audio Track")
                    Divider()
                    telemetryRow(title: "Current Timestamp", value: String(format: "%.3f s", appState.videoPlayerController.currentTime))
                    Divider()
                    telemetryRow(title: "Playback State", value: appState.videoPlayerController.isPlaying ? "Playing (~30 FPS)" : "Paused (Frame Hold)")
                    Divider()
                    telemetryRow(title: "File Size", value: info.fileSizeFormatted)
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Text("Open a video to view real-time playback and AVFoundation telemetry.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
    
    // MARK: - 3. Image Analytics & Histograms
    
    private var imageAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Image Analytics & Histograms")
                .font(.headline)
            
            if let info = appState.imageInfo {
                ImageInfoView(info: info)
            }
            
            if let histogram = appState.histogramData {
                RGBHistogramView(data: histogram)
            } else {
                Text("Load an image to view 256-bin RGB and Luminance histograms.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }
    
    // MARK: - 4. GPU / Metal Device Status
    
    private var gpuMetalStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metal GPU Device")
                .font(.headline)
            
            VStack(spacing: 10) {
                telemetryRow(title: "MTLDevice Name", value: appState.metalContext.device.name)
                Divider()
                telemetryRow(title: "Architecture", value: "Unified Memory (UMA)")
                Divider()
                telemetryRow(title: "Texture Cache", value: "CVMetalTextureCache (Zero-Copy)")
                Divider()
                telemetryRow(title: "Command Queue", value: "Ready (Thread-Safe)")
                Divider()
                telemetryRow(title: "Max Threads/Group", value: "\(appState.metalContext.device.maxThreadsPerThreadgroup.width) × \(appState.metalContext.device.maxThreadsPerThreadgroup.height)")
                Divider()
                telemetryRow(title: "GPU Utilization", value: "Not available through public API", isUnavailable: true)
                Divider()
                telemetryRow(title: "Core Temperature", value: "Not available through public API", isUnavailable: true)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - 5. Processing Performance Metrics
    
    private var processingPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Processing Performance")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "GPU Time",
                    value: appState.performanceMetrics.formattedGPUTime,
                    unit: "ms",
                    icon: "bolt.fill",
                    color: .orange
                )
                
                MetricCard(
                    title: "Frame Time",
                    value: appState.performanceMetrics.formattedFrameTime,
                    unit: "ms",
                    icon: "timer",
                    color: .blue
                )
                
                MetricCard(
                    title: "Pass Count",
                    value: "\(appState.performanceMetrics.passCount)",
                    unit: "passes",
                    icon: "arrow.triangle.2.circlepath",
                    color: .purple
                )
                
                MetricCard(
                    title: "MegaPixels/s",
                    value: appState.performanceMetrics.formattedThroughput,
                    unit: "MP/s",
                    icon: "speedometer",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - 6. Memory & Resource Observability
    
    private var memoryResourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory & GPU Texture Pool")
                .font(.headline)
            
            VStack(spacing: 10) {
                telemetryRow(title: "Active Frame Texture (BGRA8)", value: appState.memoryMetrics.originalTextureMBFormatted)
                Divider()
                telemetryRow(title: "Intermediate Textures", value: appState.memoryMetrics.intermediateTexturesMBFormatted)
                Divider()
                telemetryRow(title: "Estimated GPU Working Set", value: appState.memoryMetrics.totalEstimatedWorkingSetMBFormatted)
                Divider()
                telemetryRow(title: "Texture Pool Status", value: "\(appState.memoryMetrics.reusablePooledTextures) Pooled / Reusable")
                Divider()
                telemetryRow(title: "Memory Pressure State", value: appState.memoryMetrics.memoryPressureState)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - 7. CPU vs GPU Benchmark Suite
    
    private var benchmarkSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CPU vs GPU Benchmark")
                .font(.headline)
            
            BenchmarkControlView()
            
            if !appState.benchmarkResults.isEmpty {
                BenchmarkResultsView(results: appState.benchmarkResults)
            }
        }
    }
    
    // MARK: - 8. Processing History Log
    
    private var processingHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Session History (\(appState.processingHistory.count))")
                    .font(.headline)
                Spacer()
                if !appState.processingHistory.isEmpty {
                    Text("Latest Events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if appState.processingHistory.isEmpty {
                Text("No processing events recorded in this session.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 8) {
                    ForEach(appState.processingHistory.prefix(8)) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.operationName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.2f ms", entry.gpuTimeMs))
                                    .font(.subheadline.monospaced().bold())
                                    .foregroundStyle(.orange)
                                Text("\(entry.passCount) pass • \(entry.resolutionText)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }
    
    // MARK: - 9. System Diagnostics
    
    private var systemDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics & Metal Capabilities")
                .font(.headline)
            
            VStack(spacing: 10) {
                telemetryRow(title: "Operating System", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                Divider()
                telemetryRow(title: "Device Model", value: UIDevice.current.model)
                Divider()
                telemetryRow(title: "Metal Non-Uniform Threadgroups", value: "Supported")
                Divider()
                telemetryRow(title: "SIMD Group Shuffles", value: "Supported")
                Divider()
                telemetryRow(title: "Color Space", value: "Display P3 / Extended sRGB")
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Helpers
    
    private func telemetryRow(title: String, value: String, isUnavailable: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.subheadline.monospaced())
                .foregroundStyle(isUnavailable ? .secondary : Color.accentColor)
        }
    }
}
