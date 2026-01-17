//
//  VoiceCloningService.swift
//  EchoCorePro
//
//  Swift client for OpenVoice Python server
//

import Combine
import Foundation

/// Service for voice cloning via local OpenVoice server
actor VoiceCloningService: ServiceProtocol {

    nonisolated let serviceId = "VoiceCloningService"

    // MARK: - Properties

    private let baseURL = URL(string: "http://127.0.0.1:8765")!
    private let urlSession: URLSession
    private let logger = OSLogManager.shared

    // MARK: - Types

    struct CloneResponse: Codable {
        let speakerId: String
        let durationSeconds: Double
        let success: Bool
        let message: String

        enum CodingKeys: String, CodingKey {
            case speakerId = "speaker_id"
            case durationSeconds = "duration_seconds"
            case success, message
        }
    }

    struct HealthResponse: Codable {
        let status: String
        let modelLoaded: Bool
        let speakersLoaded: Int

        enum CodingKeys: String, CodingKey {
            case status
            case modelLoaded = "model_loaded"
            case speakersLoaded = "speakers_loaded"
        }
    }

    struct SpeakersResponse: Codable {
        let speakers: [String]
        let count: Int
    }

    enum VoiceCloningError: Error, LocalizedError {
        case serverNotRunning
        case modelNotLoaded
        case cloneFailed(String)
        case synthesizeFailed(String)
        case speakerNotFound(String)
        case invalidAudio
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .serverNotRunning:
                return
                    "OpenVoice server is not running. Start it with: python Scripts/openvoice_server.py"
            case .modelNotLoaded:
                return "OpenVoice model not loaded on server"
            case .cloneFailed(let reason):
                return "Voice cloning failed: \(reason)"
            case .synthesizeFailed(let reason):
                return "Speech synthesis failed: \(reason)"
            case .speakerNotFound(let id):
                return "Speaker '\(id)' not found. Clone a voice first."
            case .invalidAudio:
                return "Invalid audio data"
            case .networkError(let reason):
                return "Network error: \(reason)"
            }
        }
    }

    // MARK: - Initialization

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - ServiceProtocol

    func initialize() async throws {
        // Check if server is running
        let isHealthy = await checkHealth()
        if isHealthy {
            logger.log(
                "VoiceCloningService connected to OpenVoice server", category: .inference,
                level: .info)
        } else {
            logger.log(
                "VoiceCloningService: OpenVoice server not available", category: .inference,
                level: .warning)
        }
    }

    func shutdown() async {
        logger.log("VoiceCloningService shutdown", category: .inference, level: .info)
    }

    // MARK: - Health Check

    /// Check if the OpenVoice server is running
    func checkHealth() async -> Bool {
        do {
            let url = baseURL.appendingPathComponent("health")
            let (data, response) = try await urlSession.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else {
                return false
            }

            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            return health.status == "healthy"
        } catch {
            return false
        }
    }

    /// Check if the model is loaded on the server
    func isModelLoaded() async -> Bool {
        do {
            let url = baseURL.appendingPathComponent("health")
            let (data, _) = try await urlSession.data(from: url)
            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            return health.modelLoaded
        } catch {
            return false
        }
    }

    // MARK: - Voice Cloning

    /// Clone a voice from an audio file
    /// - Parameters:
    ///   - audioURL: Path to the reference audio file (WAV format, 6+ seconds)
    ///   - speakerId: Unique identifier for this cloned voice
    /// - Returns: Clone response with status
    func cloneVoice(from audioURL: URL, speakerId: String) async throws -> CloneResponse {
        guard await checkHealth() else {
            throw VoiceCloningError.serverNotRunning
        }

        logger.log("Cloning voice for speaker: \(speakerId)", category: .inference, level: .info)

        let url = baseURL.appendingPathComponent("clone")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add audio file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"audio\"; filename=\"reference.wav\"\r\n".data(
                using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add speaker_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"speaker_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(speakerId)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceCloningError.networkError("Invalid response")
        }

        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                let detail = errorData["detail"]
            {
                throw VoiceCloningError.cloneFailed(detail)
            }
            throw VoiceCloningError.cloneFailed("Status \(httpResponse.statusCode)")
        }

        let cloneResponse = try JSONDecoder().decode(CloneResponse.self, from: data)
        logger.log(
            "Voice cloned successfully: \(cloneResponse.message)", category: .inference,
            level: .info)

        return cloneResponse
    }

    /// Synthesize speech using a cloned voice
    /// - Parameters:
    ///   - text: Text to synthesize
    ///   - speakerId: ID of the cloned speaker to use
    ///   - language: Language code (default "en")
    ///   - speed: Speech speed multiplier (default 1.0)
    /// - Returns: Audio data as WAV
    func synthesize(
        text: String,
        speakerId: String,
        language: String = "en",
        speed: Float = 1.0,
        temperature: Float = 0.7,
        topP: Float = 0.8,
        repetitionPenalty: Float = 2.0,
        minP: Float = 0.05,
        cfgWeight: Float = 0.0,
        exaggeration: Float = 0.0,
        chunkSize: Int = 200,
        minChunkSeconds: Float = 2.0,
        chunkRetries: Int = 0
    ) async throws -> Data {
        guard await checkHealth() else {
            throw VoiceCloningError.serverNotRunning
        }

        guard await isModelLoaded() else {
            throw VoiceCloningError.modelNotLoaded
        }

        logger.log(
            "Synthesizing speech for speaker: \(speakerId)", category: .inference, level: .info)

        let url = baseURL.appendingPathComponent("synthesize")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "text": text,
            "speaker_id": speakerId,
            "language": language,
            "speed": speed,
            "temperature": temperature,
            "top_p": topP,
            "repetition_penalty": repetitionPenalty,
            "min_p": minP,
            "cfg_weight": cfgWeight,
            "exaggeration": exaggeration,
            "chunk_size": chunkSize,
            "chunk_min_seconds": minChunkSeconds,
            "chunk_retries": chunkRetries,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceCloningError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            logger.log(
                "Speech synthesized: \(data.count) bytes", category: .inference, level: .info)
            return data
        case 404:
            throw VoiceCloningError.speakerNotFound(speakerId)
        case 503:
            throw VoiceCloningError.modelNotLoaded
        default:
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                let detail = errorData["detail"]
            {
                throw VoiceCloningError.synthesizeFailed(detail)
            }
            throw VoiceCloningError.synthesizeFailed("Status \(httpResponse.statusCode)")
        }
    }

    /// List all cloned speakers
    func listSpeakers() async throws -> [String] {
        guard await checkHealth() else {
            throw VoiceCloningError.serverNotRunning
        }

        let url = baseURL.appendingPathComponent("speakers")
        let (data, _) = try await urlSession.data(from: url)
        let response = try JSONDecoder().decode(SpeakersResponse.self, from: data)

        return response.speakers
    }

    /// Delete a cloned speaker
    func deleteSpeaker(_ speakerId: String) async throws {
        guard await checkHealth() else {
            throw VoiceCloningError.serverNotRunning
        }

        let url = baseURL.appendingPathComponent("speakers/\(speakerId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw VoiceCloningError.speakerNotFound(speakerId)
        }

        logger.log("Deleted speaker: \(speakerId)", category: .inference, level: .info)
    }
}
