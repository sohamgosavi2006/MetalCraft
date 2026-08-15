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
    
    init(
        type: String,
        width: Int,
        height: Int,
        format: String = "unknown",
        fps: Double? = nil,
        duration: Double? = nil,
        colorSpace: String? = nil,
        histogramSummary: [String: Double]? = nil
    ) {
        self.type = type
        self.width = width
        self.height = height
        self.format = format
        self.fps = fps
        self.duration = duration
        self.colorSpace = colorSpace
        self.histogramSummary = histogramSummary
    }
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
}

// MARK: - Health Check DTO

struct AgentHealthInfo: Codable, Sendable {
    let status: String
    let service: String
    let version: String
    let hostname: String?
    var latencyMs: Double = 0.0
    var endpointURL: String = ""
}

// MARK: - Connection Status Enum

enum AgentConnectionStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case connected(endpoint: String, latencyMs: Double)
    case failed(reason: String)
    
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
    
    var displayText: String {
        switch self {
        case .disconnected: return "Agent Disconnected"
        case .connecting: return "Discovering Agent..."
        case .connected(let ep, let lat): return "Connected to \(ep) (\(Int(lat))ms)"
        case .failed(let reason): return "Connection Failed: \(reason)"
        }
    }
}

// MARK: - Agent Service Errors

enum AgentServiceError: LocalizedError, Equatable {
    case invalidEndpointURL(String)
    case requestEncodingFailed
    case responseDecodingFailed(String)
    case serverError(statusCode: Int, message: String)
    case networkUnavailable
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
        case .networkUnavailable:
            return "Unable to connect to local Agent backend on your Mac. Tap the gear icon in AI Create to auto-discover or test connection."
        case .timeout:
            return "Agent request timed out after 30 seconds."
        }
    }
}

// MARK: - Agent Service Client

final class AgentService: Sendable {
    private let session: URLSession
    
    /// Default candidate endpoints for local development
    static var defaultCandidateURLs: [String] {
        [
            "http://172.20.10.4:8080",            // Active iPhone Hotspot / LAN
            "http://admins-MacBook-Pro-8.local:8080", // Bonjour mDNS local hostname
            "http://10.3.12.210:8080",            // Alternate Wi-Fi LAN
            "http://127.0.0.1:8080"               // Simulator loopback
        ]
    }
    
    var endpointBaseURLString: String {
        get {
            UserDefaults.standard.string(forKey: "AgentEndpointURL") ?? Self.defaultCandidateURLs[0]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "AgentEndpointURL")
        }
    }
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Auto-Discovery & Health Probing
    
    /// Probes a list of candidate URLs in parallel and returns the first healthy endpoint.
    func autoDiscoverEndpoint() async -> AgentHealthInfo? {
        logger.info("[AgentConnection] Starting auto-discovery across candidates...")
        
        var candidates = [endpointBaseURLString]
        for url in Self.defaultCandidateURLs where !candidates.contains(url) {
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
                    logger.info("[AgentConnection] Auto-discovered reachable backend at \(health.endpointURL) (latency: \(health.latencyMs)ms)")
                    self.endpointBaseURLString = health.endpointURL
                    return health
                }
            }
            return nil
        }
    }
    
    /// Checks health of a specific endpoint URL with latency measurement.
    func checkHealth(at baseURL: String) async -> AgentHealthInfo? {
        guard let url = URL(string: "\(baseURL)/health") else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        
        let start = CFAbsoluteTimeGetCurrent()
        do {
            logger.debug("[AgentConnection] Probing \(baseURL)/health")
            let (data, response) = try await session.data(for: request)
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            
            guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                return nil
            }
            
            var info = try JSONDecoder().decode(AgentHealthInfo.self, from: data)
            info.latencyMs = elapsedMs
            info.endpointURL = baseURL
            return info
        } catch {
            logger.debug("[AgentConnection] Health check failed for \(baseURL): \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Creative Request Dispatch
    
    /// Sends a creative prompt and media metadata to the agent backend and returns the synthesized response.
    func sendCreativeRequest(
        prompt: String,
        mediaMetadata: MediaMetadata,
        thumbnail: UIImage? = nil,
        preferences: [String: AnyCodableValue]? = nil
    ) async throws -> AgentResponse {
        var activeBaseURL = endpointBaseURLString
        
        // Attempt fast health probe; if current is down, attempt auto-discovery
        if await checkHealth(at: activeBaseURL) == nil {
            logger.warning("[AgentConnection] Current endpoint \(activeBaseURL) unreachable. Attempting fallback discovery...")
            if let discovered = await autoDiscoverEndpoint() {
                activeBaseURL = discovered.endpointURL
            }
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
                throw AgentServiceError.networkUnavailable
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                logger.error("[AgentConnection] Agent server returned error: \(errorMsg)")
                throw AgentServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMsg)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let agentResponse = try decoder.decode(AgentResponse.self, from: data)
            logger.info("[AgentConnection] Received valid agent response with plan ID: \(agentResponse.editPlan?.planId ?? "none")")
            return agentResponse
            
        } catch let error as AgentServiceError {
            throw error
        } catch let urlError as URLError {
            logger.error("[AgentConnection] Network URLError: \(urlError.localizedDescription)")
            if urlError.code == .timedOut {
                throw AgentServiceError.timeout
            } else {
                throw AgentServiceError.networkUnavailable
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
        
        guard let url = URL(string: "\(endpointBaseURLString)/api/v1/telemetry") else { return }
        
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
}
