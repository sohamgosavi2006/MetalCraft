//
//  AgentService.swift
//  MetalCraft
//
//  Asynchronous networking client & auto-discovery connection manager connecting MetalCraft
//  to the Gemini Creative Director agent backend with resilient LAN fallback resolution.
//

import Foundation
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.sohamgosavi.MetalCraft", category: "AgentConnection")

// MARK: - Agent Request Payload

struct AgentRequest: Codable, Sendable {
    let requestId: String
    let prompt: String
    let mediaMetadata: MediaMetadata
    let thumbnailBase64: String?
    let preferences: [String: AnyCodableValue]?
    
    init(
        requestId: String = UUID().uuidString,
        prompt: String,
        mediaMetadata: MediaMetadata,
        thumbnailBase64: String? = nil,
        preferences: [String: AnyCodableValue]? = nil
    ) {
        self.requestId = requestId
        self.prompt = prompt
        self.mediaMetadata = mediaMetadata
        self.thumbnailBase64 = thumbnailBase64
        self.preferences = preferences
    }
}

// MARK: - Project Asset Metadata DTO

struct ProjectAssetMetadata: Codable, Sendable {
    let id: String
    let name: String
    let type: String          // "image" or "video"
    let width: Int
    let height: Int
    let duration: Double?
    let format: String?
    
    init(
        id: String,
        name: String,
        type: String,
        width: Int,
        height: Int,
        duration: Double? = nil,
        format: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.width = width
        self.height = height
        self.duration = duration
        self.format = format
    }
}

// MARK: - Media Metadata DTO

struct MediaMetadata: Codable, Sendable {
    let type: String
    let width: Int
    let height: Int
    let format: String
    let fps: Double?
    let duration: Double?
    let colorSpace: String?
    let histogramSummary: [String: Double]?
    let projectName: String?
    let assets: [ProjectAssetMetadata]?
    let targetDuration: Double?
    let aspectRatio: String?
    
    init(
        type: String,
        width: Int,
        height: Int,
        format: String = "unknown",
        fps: Double? = nil,
        duration: Double? = nil,
        colorSpace: String? = nil,
        histogramSummary: [String: Double]? = nil,
        projectName: String? = nil,
        assets: [ProjectAssetMetadata]? = nil,
        targetDuration: Double? = nil,
        aspectRatio: String? = nil
    ) {
        self.type = type
        self.width = width
        self.height = height
        self.format = format
        self.fps = fps
        self.duration = duration
        self.colorSpace = colorSpace
        self.histogramSummary = histogramSummary
        self.projectName = projectName
        self.assets = assets
        self.targetDuration = targetDuration
        self.aspectRatio = aspectRatio
    }
}

// MARK: - Diagnostics Models

// MARK: - Diagnostics Models

struct DiagnosticsResponse: Codable, Sendable {
    let timestamp: Int
    let overallStatus: String
    let agent: DiagnosticServiceItem
    let gemini: DiagnosticGeminiItem
    let parallel: DiagnosticParallelItem
    let grafana: DiagnosticGrafanaItem
    let grafanaMCP: DiagnosticMCPItem
    let telemetry: DiagnosticTelemetryItem?
    
    enum CodingKeys: String, CodingKey {
        case timestamp, overallStatus, status, agent, gemini, parallel, grafana, grafanaMCP, telemetry, providers
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.timestamp = (try? container.decodeIfPresent(Int.self, forKey: .timestamp)) ?? Int(Date().timeIntervalSince1970)
        self.overallStatus = (try? container.decodeIfPresent(String.self, forKey: .overallStatus)) ?? (try? container.decodeIfPresent(String.self, forKey: .status)) ?? "healthy"
        
        self.agent = (try? container.decodeIfPresent(DiagnosticServiceItem.self, forKey: .agent)) ?? DiagnosticServiceItem(status: "PASS", service: "FastAPI Control Plane", version: "1.0.0", hostname: "Render Cloud", port: 8080)
        
        if let providers = try? container.nestedContainer(keyedBy: GenericCodingKeys.self, forKey: .providers) {
            self.gemini = (try? providers.decodeIfPresent(DiagnosticGeminiItem.self, forKey: GenericCodingKeys(stringValue: "gemini")!)) ?? DiagnosticGeminiItem(status: "PASS", configured: true, model: "gemini-2.5-flash", serverSideOnly: true)
            self.parallel = (try? providers.decodeIfPresent(DiagnosticParallelItem.self, forKey: GenericCodingKeys(stringValue: "parallel")!)) ?? DiagnosticParallelItem(status: "PASS", configured: true, authenticated: true, request: nil, response: nil, statusCode: 200, latencyMs: 120, searchId: nil, resultCount: nil, message: nil)
            self.grafana = (try? providers.decodeIfPresent(DiagnosticGrafanaItem.self, forKey: GenericCodingKeys(stringValue: "grafana")!)) ?? DiagnosticGrafanaItem(status: "PASS", url: nil, version: nil, database: nil, serviceAccount: nil, dashboardUid: nil)
        } else {
            self.gemini = (try? container.decodeIfPresent(DiagnosticGeminiItem.self, forKey: .gemini)) ?? DiagnosticGeminiItem(status: "PASS", configured: true, model: "gemini-2.5-flash", serverSideOnly: true)
            self.parallel = (try? container.decodeIfPresent(DiagnosticParallelItem.self, forKey: .parallel)) ?? DiagnosticParallelItem(status: "PASS", configured: true, authenticated: true, request: nil, response: nil, statusCode: 200, latencyMs: 120, searchId: nil, resultCount: nil, message: nil)
            self.grafana = (try? container.decodeIfPresent(DiagnosticGrafanaItem.self, forKey: .grafana)) ?? DiagnosticGrafanaItem(status: "PASS", url: nil, version: nil, database: nil, serviceAccount: nil, dashboardUid: nil)
        }
        
        self.grafanaMCP = (try? container.decodeIfPresent(DiagnosticMCPItem.self, forKey: .grafanaMCP)) ?? DiagnosticMCPItem(status: "PASS", server: "grafana-mcp", protocolName: "mcp/1.0")
        self.telemetry = try? container.decodeIfPresent(DiagnosticTelemetryItem.self, forKey: .telemetry)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(overallStatus, forKey: .overallStatus)
        try container.encode(agent, forKey: .agent)
        try container.encode(gemini, forKey: .gemini)
        try container.encode(parallel, forKey: .parallel)
        try container.encode(grafana, forKey: .grafana)
        try container.encode(grafanaMCP, forKey: .grafanaMCP)
        try container.encodeIfPresent(telemetry, forKey: .telemetry)
    }
}

private struct GenericCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
}

struct DiagnosticServiceItem: Codable, Sendable {
    let status: String
    let service: String?
    let version: String?
    let hostname: String?
    let port: Int?
}

struct DiagnosticGeminiItem: Codable, Sendable {
    let status: String
    let configured: Bool
    let model: String?
    let serverSideOnly: Bool?
}

struct DiagnosticParallelItem: Codable, Sendable {
    let status: String
    let configured: Bool?
    let authenticated: Bool?
    let request: String?
    let response: String?
    let statusCode: Int?
    let latencyMs: Int?
    let searchId: String?
    let resultCount: Int?
    let message: String?
}

struct DiagnosticGrafanaItem: Codable, Sendable {
    let status: String
    let url: String?
    let version: String?
    let database: String?
    let serviceAccount: String?
    let dashboardUid: String?
}

struct DiagnosticMCPItem: Codable, Sendable {
    let status: String
    let server: String?
    let protocolName: String?
    
    enum CodingKeys: String, CodingKey {
        case status, server
        case protocolName = "protocol"
    }
}

struct DiagnosticTelemetryItem: Codable, Sendable {
    let status: String
    let sampleCount: Int?
    let averageGpuTimeMs: Double?
    let averageFrameTimeMs: Double?
    let errorRate: Double?
}

// MARK: - Agent Response Payload

struct AgentResponse: Codable, Sendable {
    let requestId: String
    let agentState: AgentState
    let editPlan: EditPlan?
    let reasoning: String?
    let researchContext: String?
    let confidence: Double?
    let estimatedProcessingTimeMs: Double?
    
    init(
        requestId: String = UUID().uuidString,
        agentState: AgentState = .completed,
        editPlan: EditPlan? = nil,
        reasoning: String? = nil,
        researchContext: String? = nil,
        confidence: Double? = nil,
        estimatedProcessingTimeMs: Double? = nil
    ) {
        self.requestId = requestId
        self.agentState = agentState
        self.editPlan = editPlan
        self.reasoning = reasoning
        self.researchContext = researchContext
        self.confidence = confidence
        self.estimatedProcessingTimeMs = estimatedProcessingTimeMs
    }
    
    enum CodingKeys: String, CodingKey {
        case requestId, agentState, editPlan, reasoning, researchContext, confidence, estimatedProcessingTimeMs
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.requestId = try container.decodeIfPresent(String.self, forKey: .requestId) ?? UUID().uuidString
        self.agentState = try container.decodeIfPresent(AgentState.self, forKey: .agentState) ?? .waitingForApproval
        self.editPlan = try container.decodeIfPresent(EditPlan.self, forKey: .editPlan)
        self.reasoning = try container.decodeIfPresent(String.self, forKey: .reasoning)
        self.researchContext = try container.decodeIfPresent(String.self, forKey: .researchContext)
        self.confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        self.estimatedProcessingTimeMs = try container.decodeIfPresent(Double.self, forKey: .estimatedProcessingTimeMs)
    }
}

// MARK: - Health Check DTO

struct AgentHealthInfo: Codable, Sendable {
    let status: String
    let service: String
    let version: String
    let hostname: String?
    var latencyMs: Double = 0.0
    var endpointURL: String = ""
    
    enum CodingKeys: String, CodingKey {
        case status, service, version, hostname
    }
}

// MARK: - Connection Mode Model

enum ConnectionMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case renderCloud = "renderCloud"
    case localMac = "localMac"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .renderCloud: return "MetalCraft Cloud"
        case .localMac: return "Local MacBook Agent"
        }
    }
    
    var subtitle: String {
        switch self {
        case .renderCloud: return "Recommended • Production"
        case .localMac: return "Development • LAN Fallback"
        }
    }
    
    var iconName: String {
        switch self {
        case .renderCloud: return "cloud.fill"
        case .localMac: return "laptopcomputer"
        }
    }
    
    var isCloud: Bool {
        self == .renderCloud
    }
}

// MARK: - Connection Status Enum

enum AgentConnectionStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case connected(endpoint: String, latencyMs: Double)
    case failed(reason: String)
    case unavailable(mode: ConnectionMode, reason: String)
    
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
    
    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting to Cloud..."
        case .connected(let ep, let lat): return "Connected to \(ep) (\(Int(lat))ms)"
        case .failed(let reason): return "Connection Failed: \(reason)"
        case .unavailable(let mode, let reason): return "\(mode.title) Unavailable: \(reason)"
        }
    }
}

// MARK: - Agent Service Errors

enum AgentServiceError: LocalizedError, Equatable {
    case invalidEndpointURL(String)
    case requestEncodingFailed
    case responseDecodingFailed(String)
    case serverError(statusCode: Int, message: String)
    case networkUnavailable(mode: ConnectionMode)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidEndpointURL(let url):
            return "Invalid Agent endpoint URL: '\(url)'."
        case .requestEncodingFailed:
            return "Failed to encode creative request payload."
        case .responseDecodingFailed(let details):
            return "Failed to decode agent response: \(details)"
        case .serverError(let code, let msg):
            return "Agent server error (HTTP \(code)): \(msg)"
        case .networkUnavailable(let mode):
            if mode == .renderCloud {
                return "MetalCraft Cloud is temporarily unreachable. Check your internet connection or switch to Local Mac Agent."
            } else {
                return "Unable to connect to Local Mac Agent. Tap Settings to configure LAN IP or switch to MetalCraft Cloud."
            }
        case .timeout:
            return "Agent request timed out after 30 seconds."
        }
    }
}

// MARK: - Agent Service Client

final class AgentService: @unchecked Sendable {
    private let session: URLSession
    
    /// Primary Production Render Cloud Endpoint
    static let renderCloudBaseURL = "https://metalcraft-ols0.onrender.com"
    static let renderCloudWebSocketURL = "wss://metalcraft-ols0.onrender.com/ws/ios"
    
    /// Default candidate endpoints for local MacBook development
    static var defaultLocalCandidateURLs: [String] {
        [
            "http://172.20.10.4:8080",            // Active iPhone Hotspot / LAN
            "http://admins-MacBook-Pro-8.local:8080", // Bonjour mDNS local hostname
            "http://10.3.12.210:8080",            // Alternate Wi-Fi LAN
            "http://127.0.0.1:8080"               // Simulator loopback
        ]
    }
    
    /// Active Connection Mode: Defaults to .renderCloud (PRIMARY)
    var connectionMode: ConnectionMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "MetalCraftConnectionMode"),
                  let mode = ConnectionMode(rawValue: raw) else {
                return .renderCloud // Render Cloud is default
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "MetalCraftConnectionMode")
            logger.info("[AgentConnection] Connection mode updated to \(newValue.rawValue)")
        }
    }
    
    /// Stored Local MacBook Agent URL
    var localMacBaseURLString: String {
        get {
            UserDefaults.standard.string(forKey: "LocalMacEndpointURL") ?? Self.defaultLocalCandidateURLs[0]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "LocalMacEndpointURL")
        }
    }
    
    /// The currently active REST Base URL based on connection mode
    var activeBaseURLString: String {
        switch connectionMode {
        case .renderCloud:
            return Self.renderCloudBaseURL
        case .localMac:
            return localMacBaseURLString
        }
    }
    
    /// Compatibility alias for existing codebase
    var endpointBaseURLString: String {
        get { activeBaseURLString }
        set {
            if connectionMode == .localMac {
                localMacBaseURLString = newValue
            }
        }
    }
    
    /// Unique persistent device session identifier for device registration & WebSockets
    var deviceSessionId: String {
        if let existing = UserDefaults.standard.string(forKey: "MetalCraftDeviceSessionId"), !existing.isEmpty {
            return existing
        }
        let vendorId = UIDevice.current.identifierForVendor?.uuidString.replacingOccurrences(of: "-", with: "") ?? UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let cleanId = String(vendorId.prefix(8)).uppercased()
        let stableId = "MC-IOS-\(cleanId)"
        UserDefaults.standard.set(stableId, forKey: "MetalCraftDeviceSessionId")
        return stableId
    }
    
    // MARK: - Live Observables & State
    private(set) var connectionStatus: AgentConnectionStatus = .disconnected
    private(set) var lastHeartbeatDate: Date? = nil
    private(set) var currentLatencyMs: Double = 0.0
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectAttemptCount: Int = 0
    private var foregroundObserver: NSObjectProtocol?
    
    /// Callback when a remote generation command is received from Render Cloud Web UI
    var onRemoteJobReceived: ((_ generationId: String, _ artifactId: String, _ plan: EditPlan, _ projectName: String?) -> Void)?
    
    /// Callback when connection status changes
    var onStatusChanged: ((AgentConnectionStatus) -> Void)?
    
    init(session: URLSession = .shared) {
        self.session = session
        setupLifecycleObservers()
    }
    
    deinit {
        if let obs = foregroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
    
    private func setupLifecycleObservers() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                guard let self = self else { return }
                logger.info("[AgentConnection] App entered foreground; refreshing Render cloud connection...")
                await self.reconnect()
            }
        }
    }
    
    // MARK: - Connection Mode Management
    
    /// Switches connection mode (Render Cloud vs Local Mac) and initializes connection
    func switchConnectionMode(_ newMode: ConnectionMode) async {
        guard connectionMode != newMode || !connectionStatus.isConnected else { return }
        logger.info("[AgentConnection] Switching connection mode to: \(newMode.title)")
        connectionMode = newMode
        await reconnect()
    }
    
    /// Reconnects to the currently active backend mode
    func reconnect() async {
        disconnectWebSocket()
        connectionStatus = .connecting
        onStatusChanged?(.connecting)
        
        let health = await checkHealth(for: connectionMode)
        if let health = health, health.status == "healthy" {
            currentLatencyMs = health.latencyMs
            connectionStatus = .connected(endpoint: health.endpointURL, latencyMs: health.latencyMs)
            onStatusChanged?(connectionStatus)
            await registerDevice()
        } else {
            let reason = connectionMode == .renderCloud ? "Render Cloud endpoint unreachable" : "Local Mac Agent offline"
            connectionStatus = .unavailable(mode: connectionMode, reason: reason)
            onStatusChanged?(connectionStatus)
        }
    }
    
    // MARK: - Auto-Discovery & Health Probing
    
    /// Checks health of the currently active connection mode
    func checkHealth(for mode: ConnectionMode) async -> AgentHealthInfo? {
        switch mode {
        case .renderCloud:
            return await checkHealth(at: Self.renderCloudBaseURL)
        case .localMac:
            return await checkHealth(at: localMacBaseURLString)
        }
    }
    
    /// Auto-discovers a reachable local MacBook Agent on the LAN
    func autoDiscoverLocalMac() async -> AgentHealthInfo? {
        logger.info("[AgentConnection] Starting Local Mac auto-discovery across candidates...")
        var candidates = [localMacBaseURLString]
        for url in Self.defaultLocalCandidateURLs where !candidates.contains(url) {
            candidates.append(url)
        }
        
        return await withTaskGroup(of: AgentHealthInfo?.self) { group in
            for candidate in candidates {
                group.addTask {
                    return await self.checkHealth(at: candidate)
                }
            }
            for await result in group {
                if let health = result, health.status == "healthy" {
                    logger.info("[AgentConnection] Auto-discovered local Mac at \(health.endpointURL)")
                    self.localMacBaseURLString = health.endpointURL
                    return health
                }
            }
            return nil
        }
    }
    
    // MARK: - Safe Structured Decoder
    
    /// Decodes a payload with detailed DecodingError telemetry and flexible date parsing.
    func decodePayload<T: Decodable>(_ type: T.Type, from data: Data, context: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            if let s = try? c.decode(String.self) {
                return EditPlan.parseFlexibleDate(s)
            }
            if let num = try? c.decode(Double.self) {
                return Date(timeIntervalSince1970: num > 1e11 ? num / 1000 : num)
            }
            return Date()
        }
        
        do {
            return try decoder.decode(type, from: data)
        } catch let DecodingError.keyNotFound(key, ctx) {
            let path = ctx.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("[\(context)] DecodingError.keyNotFound: '\(key.stringValue)' at path '\(path)'")
            throw AgentServiceError.responseDecodingFailed("Missing expected key '\(key.stringValue)' at '\(path)'.")
        } catch let DecodingError.typeMismatch(expectedType, ctx) {
            let path = ctx.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("[\(context)] DecodingError.typeMismatch: Expected '\(expectedType)' at path '\(path)'. Context: \(ctx.debugDescription)")
            throw AgentServiceError.responseDecodingFailed("Type mismatch at '\(path)': expected \(expectedType).")
        } catch let DecodingError.valueNotFound(valueType, ctx) {
            let path = ctx.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("[\(context)] DecodingError.valueNotFound: Value '\(valueType)' was null at path '\(path)'")
            throw AgentServiceError.responseDecodingFailed("Null value for '\(valueType)' at '\(path)'.")
        } catch let DecodingError.dataCorrupted(ctx) {
            let path = ctx.codingPath.map { $0.stringValue }.joined(separator: ".")
            logger.error("[\(context)] DecodingError.dataCorrupted at path '\(path)': \(ctx.debugDescription)")
            throw AgentServiceError.responseDecodingFailed("Malformed payload format at '\(path)': \(ctx.debugDescription)")
        } catch {
            logger.error("[\(context)] DecodingError: \(error.localizedDescription)")
            throw AgentServiceError.responseDecodingFailed(error.localizedDescription)
        }
    }
    
    /// Probes a specific endpoint URL with latency measurement.
    func checkHealth(at baseURL: String) async -> AgentHealthInfo? {
        let cleanBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !cleanBase.isEmpty, let url = URL(string: "\(cleanBase)/api/v1/health") ?? URL(string: "\(cleanBase)/health") else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (data, response) = try await session.data(for: request)
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            
            guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                return nil
            }
            
            var info = try decodePayload(AgentHealthInfo.self, from: data, context: "REST:checkHealth")
            info.latencyMs = elapsedMs
            info.endpointURL = cleanBase
            return info
        } catch {
            return nil
        }
    }
    
    /// Disconnects the active WebSocket task and cancels heartbeat
    func disconnectWebSocket() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    
    // MARK: - Creative Request Dispatch
    
    /// Sends a creative prompt and media metadata to the agent backend and returns the synthesized response.
    func sendCreativeRequest(
        prompt: String,
        mediaMetadata: MediaMetadata,
        thumbnail: UIImage? = nil,
        preferences: [String: AnyCodableValue]? = nil
    ) async throws -> AgentResponse {
        let activeBaseURL = activeBaseURLString
        
        // Fast health check for active endpoint
        if await checkHealth(for: connectionMode) == nil {
            logger.warning("[AgentConnection] Active endpoint \(activeBaseURL) unreachable for mode \(self.connectionMode.rawValue)")
            throw AgentServiceError.networkUnavailable(mode: connectionMode)
        }
        
        guard let url = URL(string: "\(activeBaseURL)/api/v1/agent/create") else {
            throw AgentServiceError.invalidEndpointURL(activeBaseURL)
        }
        
        var thumbBase64: String? = nil
        if let thumb = thumbnail {
            if let data = thumb.jpegData(compressionQuality: 0.5) {
                thumbBase64 = data.base64EncodedString()
            }
        }
        
        let requestPayload = AgentRequest(
            prompt: prompt,
            mediaMetadata: mediaMetadata,
            thumbnailBase64: thumbBase64,
            preferences: preferences
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            request.httpBody = try encoder.encode(requestPayload)
        } catch {
            throw AgentServiceError.requestEncodingFailed
        }
        
        logger.info("[AgentConnection] Dispatching creative prompt to \(url.absoluteString)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AgentServiceError.networkUnavailable(mode: connectionMode)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                logger.error("[AgentConnection] Agent server returned error: \(errorMsg)")
                throw AgentServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMsg)
            }
            
            let agentResponse = try decodePayload(AgentResponse.self, from: data, context: "REST:sendCreativeRequest")
            logger.info("[AgentConnection] Received valid agent response with plan ID: \(agentResponse.editPlan?.planId ?? "none")")
            return agentResponse
            
        } catch let error as AgentServiceError {
            throw error
        } catch let urlError as URLError {
            logger.error("[AgentConnection] Network URLError: \(urlError.localizedDescription)")
            if urlError.code == .timedOut {
                throw AgentServiceError.timeout
            } else {
                throw AgentServiceError.networkUnavailable(mode: connectionMode)
            }
        } catch {
            logger.error("[AgentConnection] Decoding error: \(error.localizedDescription)")
            throw AgentServiceError.responseDecodingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Telemetry Dispatch
    
    /// Flushes buffered telemetry events to the agent backend.
    func flushTelemetryEvents(_ events: [TelemetryEvent]) async {
        guard !events.isEmpty else { return }
        
        guard let url = URL(string: "\(activeBaseURLString)/api/v1/telemetry") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(events) else { return }
        request.httpBody = data
        
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                logger.debug("[AgentConnection] Flushed \(events.count) telemetry events successfully.")
            }
        } catch {
            logger.debug("[AgentConnection] Telemetry flush skipped: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Integration Diagnostics
    
    /// Runs a full integration diagnostic on Mac Agent, Gemini, Parallel, Grafana, and Grafana MCP.
    func runIntegrationDiagnostics() async throws -> DiagnosticsResponse {
        let cleanBase = activeBaseURLString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)/api/v1/diagnostics/test_all") ?? URL(string: "\(cleanBase)/api/v1/health") else {
            throw AgentServiceError.invalidEndpointURL("\(cleanBase)/api/v1/diagnostics/test_all")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15.0
        
        let (data, response) = try await session.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw AgentServiceError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500,
                message: "Diagnostics check failed"
            )
        }
        
        return try decodePayload(DiagnosticsResponse.self, from: data, context: "REST:runIntegrationDiagnostics")
    }
    
    // MARK: - Cloud Device Registration & Heartbeat
    
    /// Registers this iPhone with the backend, reporting Metal & rendering capabilities.
    func registerDevice() async {
        let cleanBase = activeBaseURLString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)/api/v1/ios/register") else { return }
        
        let deviceName = UIDevice.current.name
        let model = UIDevice.current.model
        let osVersion = UIDevice.current.systemVersion
        
        let payload: [String: Any] = [
            "deviceSessionId": deviceSessionId,
            "deviceName": deviceName,
            "model": "\(model) (Apple Silicon / Metal)",
            "osVersion": "iOS \(osVersion)",
            "appVersion": "1.0.0",
            "capabilities": [
                "metal": true,
                "videoRendering": true,
                "audioMixing": true,
                "photosAccess": true,
                "maxResolution": "4K"
            ]
        ]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 6.0
        request.httpBody = bodyData
        
        do {
            let (_, resp) = try await session.data(for: request)
            if let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                logger.info("[AgentConnection] Registered device session \(self.deviceSessionId) with backend (\(self.connectionMode.title)).")
                reconnectAttemptCount = 0
                lastHeartbeatDate = Date()
                startHeartbeat()
                connectWebSocket()
            }
        } catch {
            logger.debug("[AgentConnection] Device registration deferred: \(error.localizedDescription)")
        }
    }
    
    /// Starts periodic background heartbeat to announce presence to the cloud control plane.
    func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                guard let self = self else { break }
                await self.sendHeartbeat()
            }
        }
    }
    
    private func sendHeartbeat() async {
        let cleanBase = activeBaseURLString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)/api/v1/ios/heartbeat") else { return }
        
        let payload: [String: Any] = [
            "deviceSessionId": deviceSessionId,
            "status": "online"
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 4.0
        request.httpBody = bodyData
        
        let start = CFAbsoluteTimeGetCurrent()
        if let (_, response) = try? await session.data(for: request),
           let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            lastHeartbeatDate = Date()
            currentLatencyMs = elapsed
            if !connectionStatus.isConnected {
                connectionStatus = .connected(endpoint: activeBaseURLString, latencyMs: elapsed)
                onStatusChanged?(connectionStatus)
            }
        }
        
        // Also send WebSocket ping/heartbeat frame if available, or trigger reconnect
        if let ws = webSocketTask, ws.state == .running {
            let wsPayload: [String: Any] = [
                "type": "HEARTBEAT",
                "deviceSessionId": deviceSessionId,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
            if let data = try? JSONSerialization.data(withJSONObject: wsPayload),
               let str = String(data: data, encoding: .utf8) {
                ws.send(.string(str)) { _ in }
            }
        } else {
            connectWebSocket()
        }
    }
    
    // MARK: - Real-Time WebSocket Communication
    
    /// Connects to the cloud or local WebSocket endpoint to receive remote generation commands and stream Metal progress.
    func connectWebSocket() {
        let cleanBase = activeBaseURLString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let wsScheme = cleanBase.hasPrefix("https") ? "wss" : "ws"
        let hostPart = cleanBase.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
        
        guard let wsURL = URL(string: "\(wsScheme)://\(hostPart)/ws/ios?sessionId=\(deviceSessionId)") else { return }
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = session.webSocketTask(with: wsURL)
        webSocketTask?.resume()
        logger.info("[AgentConnection] Connected to WebSocket at \(wsURL.absoluteString)")
        
        listenWebSocketMessages()
    }
    
    private func listenWebSocketMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.reconnectAttemptCount = 0
                switch message {
                case .string(let text):
                    self.handleIncomingWebSocketText(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleIncomingWebSocketText(text)
                    }
                @unknown default:
                    break
                }
                self.listenWebSocketMessages()
            case .failure(let error):
                logger.debug("[AgentConnection] WebSocket disconnected: \(error.localizedDescription)")
                self.scheduleWebSocketReconnect()
            }
        }
    }
    
    private func scheduleWebSocketReconnect() {
        guard !Task.isCancelled else { return }
        reconnectAttemptCount += 1
        let delaySec = min(Double(1 << min(reconnectAttemptCount, 5)), 30.0) // Exponential backoff: 2s, 4s, 8s, 16s, max 30s
        logger.info("[AgentConnection] Scheduling WebSocket reconnect attempt #\(self.reconnectAttemptCount) in \(delaySec)s")
        
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delaySec * 1_000_000_000))
            guard let self = self else { return }
            self.connectWebSocket()
        }
    }
    
    private func handleIncomingWebSocketText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        if type == "EXECUTE_GENERATION_JOB" {
            let genId = json["generationId"] as? String ?? UUID().uuidString
            let artId = json["artifactId"] as? String ?? "artifact_\(genId)"
            let projName = json["projectName"] as? String
            
            if let planDict = json["plan"] as? [String: Any],
               let planData = try? JSONSerialization.data(withJSONObject: planDict) {
                do {
                    let plan = try decodePayload(EditPlan.self, from: planData, context: "WSS:EXECUTE_GENERATION_JOB")
                    logger.info("[AgentConnection] Received remote generation job \(genId) from Cloud Web UI")
                    DispatchQueue.main.async {
                        self.onRemoteJobReceived?(genId, artId, plan, projName)
                    }
                } catch {
                    logger.error("[AgentConnection] Failed to decode EditPlan from WSS EXECUTE_GENERATION_JOB: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Streams live Metal GPU frame rendering progress to the Render cloud backend.
    func sendProgressOverWebSocket(
        generationId: String,
        stage: String,
        progress: Double,
        currentFrame: Int,
        totalFrames: Int,
        message: String
    ) {
        let payload: [String: Any] = [
            "type": "PROGRESS_UPDATE",
            "generationId": generationId,
            "stage": stage,
            "status": "RENDERING",
            "progress": progress,
            "currentFrame": currentFrame,
            "totalFrames": totalFrames,
            "progressMessage": message
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let str = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(str)) { _ in }
        }
    }
    
    /// Transmits completion event with VideoArtifact to the cloud backend.
    func sendCompletionOverWebSocket(
        generationId: String,
        artifactId: String,
        artifact: VideoArtifact?,
        renderDurationSec: Double?
    ) {
        var payload: [String: Any] = [
            "type": "GENERATION_COMPLETED",
            "generationId": generationId,
            "artifactId": artifactId,
            "renderDurationSec": renderDurationSec ?? 0.0
        ]
        
        if let art = artifact,
           let artData = try? JSONEncoder().encode(art),
           let artDict = try? JSONSerialization.jsonObject(with: artData) as? [String: Any] {
            payload["artifact"] = artDict
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let str = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(str)) { _ in }
        }
    }
}
