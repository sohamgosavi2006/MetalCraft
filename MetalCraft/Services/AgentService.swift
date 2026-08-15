//
//  AgentService.swift
//  MetalCraft
//
//  HTTP / REST Networking client for communicating with the Gemini Creative Director agent backend.
//  Supports local Mac development runtime (http://127.0.0.1:8080) and Google Cloud Run endpoints.
//

import Foundation
import UIKit

// MARK: - Media Metadata DTO

struct MediaMetadata: Codable, Sendable, Equatable {
    var type: String             // "image" or "video"
    var width: Int
    var height: Int
    var format: String
    var fps: Float?
    var duration: Double?
    var histogramSummary: [String: Double]?
    
    init(
        type: String = "image",
        width: Int,
        height: Int,
        format: String = "jpeg",
        fps: Float? = nil,
        duration: Double? = nil,
        histogramSummary: [String: Double]? = nil
    ) {
        self.type = type
        self.width = width
        self.height = height
        self.format = format
        self.fps = fps
        self.duration = duration
        self.histogramSummary = histogramSummary
    }
}

// MARK: - Agent Request DTO

struct AgentRequest: Codable, Sendable, Equatable {
    var requestId: String
    var prompt: String
    var mediaMetadata: MediaMetadata
    var thumbnailBase64: String?
    var preferences: [String: AnyCodableValue]?
    
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

// MARK: - Agent Response DTO

struct AgentResponse: Codable, Sendable, Equatable {
    var requestId: String
    var agentState: AgentState
    var editPlan: EditPlan?
    var reasoning: String?
    var researchContext: String?
    var confidence: Double?
    var estimatedProcessingTimeMs: Double?
    
    init(
        requestId: String,
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
            return "Unable to connect to local/cloud Agent backend. Ensure the backend server is running."
        case .timeout:
            return "Agent request timed out after 30 seconds."
        }
    }
}

// MARK: - Agent Service Client

final class AgentService: Sendable {
    private let session: URLSession
    
    /// Default local development endpoint (dynamically resolves Mac IP on physical iOS devices)
    static var defaultEndpointURL: String {
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:8080"
        #else
        return "http://10.3.12.210:8080"
        #endif
    }
    
    var endpointBaseURLString: String {
        get {
            UserDefaults.standard.string(forKey: "AgentEndpointURL") ?? Self.defaultEndpointURL
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "AgentEndpointURL")
        }
    }
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Sends a creative prompt and media metadata to the agent backend and returns the synthesized response.
    func sendCreativeRequest(
        prompt: String,
        mediaMetadata: MediaMetadata,
        thumbnail: UIImage? = nil,
        preferences: [String: AnyCodableValue]? = nil
    ) async throws -> AgentResponse {
        guard let url = URL(string: "\(endpointBaseURLString)/api/v1/agent/create") else {
            throw AgentServiceError.invalidEndpointURL(endpointBaseURLString)
        }
        
        var thumbBase64: String? = nil
        if let thumb = thumbnail {
            // Compress thumbnail to low-res (< 80KB) for fast transfer
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
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AgentServiceError.networkUnavailable
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                throw AgentServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMsg)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                return try decoder.decode(AgentResponse.self, from: data)
            } catch {
                throw AgentServiceError.responseDecodingFailed(error.localizedDescription)
            }
        } catch let err as AgentServiceError {
            throw err
        } catch let urlErr as URLError where urlErr.code == .timedOut {
            throw AgentServiceError.timeout
        } catch {
            throw AgentServiceError.networkUnavailable
        }
    }
    
    /// Flushes a batch of telemetry events to the backend telemetry collector.
    func sendTelemetryBatch(events: [TelemetryEvent]) async throws -> Bool {
        guard !events.isEmpty else { return true }
        guard let url = URL(string: "\(endpointBaseURLString)/api/v1/telemetry") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try? encoder.encode(events)
        
        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }
}
