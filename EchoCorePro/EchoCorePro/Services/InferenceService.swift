//
//  InferenceService.swift
//  EchoCorePro
//
//  CoreML-based speech-to-text inference using WhisperKit
//

import AVFoundation
import Combine
import Foundation
import WhisperKit

/// Inference service managing speech-to-text using WhisperKit
actor InferenceService: ServiceProtocol {

    // MARK: - ServiceProtocol

    nonisolated let serviceId = "InferenceService"

    // MARK: - Properties

    private var whisperKit: WhisperKit?
    private var isModelLoaded = false
    private var currentModelName: String?
    private let logger = OSLogManager.shared

    // MARK: - Types

    struct TranscriptionResult: Sendable {
        let text: String
        let confidence: Double
        let processingTimeMs: Int
        let language: String?
        let segments: [TranscriptionSegment]
    }

    struct TranscriptionSegment: Sendable {
        let text: String
        let startTime: Double
        let endTime: Double
        let confidence: Double
    }

    enum InferenceError: Error, LocalizedError {
        case modelNotLoaded
        case audioRecordingFailed(String)
        case transcriptionFailed(String)
        case invalidAudioFormat
        case modelLoadFailed(String)

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "No model is currently loaded"
            case .audioRecordingFailed(let reason):
                return "Audio recording failed: \(reason)"
            case .transcriptionFailed(let reason):
                return "Transcription failed: \(reason)"
            case .invalidAudioFormat:
                return "Invalid audio format"
            case .modelLoadFailed(let reason):
                return "Failed to load model: \(reason)"
            }
        }
    }

    // MARK: - Initialization

    init() {}

    // MARK: - ServiceProtocol Implementation

    func initialize() async throws {
        logger.log("InferenceService initialized", category: .inference, level: .info)
    }

    func shutdown() async {
        await unloadModel()
        logger.log("InferenceService shutdown", category: .inference, level: .info)
    }

    // MARK: - Model Management

    /// Load a WhisperKit model for transcription
    /// - Parameter modelName: Name of the model to load (e.g., "base", "small", "large-v3")
    func loadModel(named modelName: String) async throws {
        logger.log("Loading WhisperKit model: \(modelName)", category: .inference, level: .info)

        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Create WhisperKit configuration
            let config = WhisperKitConfig(model: modelName)

            // Initialize WhisperKit - this will download the model if needed
            whisperKit = try await WhisperKit(config)

            isModelLoaded = true
            currentModelName = modelName

            let loadTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.log(
                "WhisperKit model '\(modelName)' loaded in \(Int(loadTime))ms",
                category: .inference, level: .info)
        } catch {
            logger.log(
                "Failed to load WhisperKit model: \(error)", category: .inference, level: .error
            )
            throw InferenceError.modelLoadFailed(error.localizedDescription)
        }
    }

    /// Unload the current model to free memory
    func unloadModel() async {
        if isModelLoaded {
            whisperKit = nil
            isModelLoaded = false
            currentModelName = nil
            logger.log("WhisperKit model unloaded", category: .inference, level: .info)
        }
    }

    /// Check if a model is currently loaded
    var modelLoaded: Bool {
        isModelLoaded
    }

    /// Get the name of the currently loaded model
    var loadedModelName: String? {
        currentModelName
    }

    // MARK: - Transcription

    /// Transcribe audio from a file path
    /// - Parameter audioPath: Path to the audio file
    /// - Returns: Transcription result with text and metadata
    func transcribe(audioPath: URL) async throws -> TranscriptionResult {
        guard let whisperKit = whisperKit else {
            throw InferenceError.modelNotLoaded
        }

        logger.log(
            "Transcribing audio: \(audioPath.lastPathComponent)", category: .inference, level: .info
        )

        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Use WhisperKit to transcribe the audio file
            let results = try await whisperKit.transcribe(audioPath: audioPath.path)

            let processingTime = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

            // Extract text from all results
            let fullText = results.map { $0.text }.joined(separator: " ")

            // Convert WhisperKit segments to our format
            var segments: [TranscriptionSegment] = []
            for result in results {
                for segment in result.segments {
                    segments.append(
                        TranscriptionSegment(
                            text: segment.text,
                            startTime: Double(segment.start),
                            endTime: Double(segment.end),
                            confidence: Double(segment.avgLogprob)
                        ))
                }
            }

            let result = TranscriptionResult(
                text: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: 0.95,
                processingTimeMs: processingTime,
                language: results.first?.language,
                segments: segments
            )

            logger.log(
                "Transcription complete in \(processingTime)ms: \"\(result.text.prefix(50))...\"",
                category: .inference, level: .info)

            return result
        } catch {
            logger.log("Transcription failed: \(error)", category: .inference, level: .error)
            throw InferenceError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Transcribe audio from raw audio samples
    /// - Parameters:
    ///   - samples: Audio samples as float array
    ///   - sampleRate: Sample rate of the audio (default 16000 for Whisper)
    /// - Returns: Transcription result
    func transcribe(samples: [Float], sampleRate: Int = 16000) async throws -> TranscriptionResult {
        guard let whisperKit = whisperKit else {
            throw InferenceError.modelNotLoaded
        }

        logger.log(
            "Transcribing \(samples.count) samples at \(sampleRate)Hz", category: .inference,
            level: .info)

        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Use WhisperKit to transcribe audio array directly
            let results = try await whisperKit.transcribe(audioArray: samples)

            let processingTime = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

            let fullText = results.map { $0.text }.joined(separator: " ")

            var segments: [TranscriptionSegment] = []
            for result in results {
                for segment in result.segments {
                    segments.append(
                        TranscriptionSegment(
                            text: segment.text,
                            startTime: Double(segment.start),
                            endTime: Double(segment.end),
                            confidence: Double(segment.avgLogprob)
                        ))
                }
            }

            return TranscriptionResult(
                text: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: 0.92,
                processingTimeMs: processingTime,
                language: results.first?.language,
                segments: segments
            )
        } catch {
            logger.log("Transcription failed: \(error)", category: .inference, level: .error)
            throw InferenceError.transcriptionFailed(error.localizedDescription)
        }
    }

    // MARK: - Utility

    /// Get recommended model for the current device based on available memory
    static func recommendedModel() -> String {
        let memory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(memory) / 1_000_000_000

        if memoryGB >= 32 {
            return "large-v3"
        } else if memoryGB >= 16 {
            return "distil-large-v3"
        } else if memoryGB >= 8 {
            return "small"
        } else {
            return "base"
        }
    }

    /// List available WhisperKit models
    static let availableModels = [
        "tiny",
        "tiny.en",
        "base",
        "base.en",
        "small",
        "small.en",
        "medium",
        "medium.en",
        "large-v2",
        "large-v3",
        "large-v3-turbo",
        "distil-large-v3",
    ]
}
