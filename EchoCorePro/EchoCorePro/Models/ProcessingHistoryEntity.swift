//
//  ProcessingHistoryEntity.swift
//  EchoCorePro
//
//  SwiftData model for processing history logs
//

import Foundation
import SwiftData

/// Type of processing operation
enum ProcessingType: String, Codable, CaseIterable {
    case speechToText = "Speech to Text"
    case textToSpeech = "Text to Speech"
    case audioPostProcessing = "Audio Processing"
    
    var icon: String {
        switch self {
        case .speechToText: return "mic.fill"
        case .textToSpeech: return "speaker.wave.3.fill"
        case .audioPostProcessing: return "waveform"
        }
    }
}

/// Represents a processing history entry
@Model
final class ProcessingHistoryEntity {
    /// Unique identifier
    @Attribute(.unique) var id: UUID
    
    /// Model ID used for processing
    var modelId: UUID?
    
    /// Model name for display
    var modelName: String
    
    /// Type of processing
    var processingTypeRaw: String
    
    /// Input length (seconds for audio, characters for text)
    var inputLength: Double
    
    /// Output length (characters for STT, seconds for TTS)
    var outputLength: Double
    
    /// Processing time in milliseconds
    var processingTimeMs: Int
    
    /// Timestamp of the operation
    var timestamp: Date
    
    /// Confidence score (for STT)
    var confidence: Double?
    
    /// Input text (for TTS) or output text (for STT)
    var textContent: String?
    
    /// Whether the operation was successful
    var wasSuccessful: Bool
    
    /// Error message if failed
    var errorMessage: String?
    
    // MARK: - Computed Properties
    
    var processingType: ProcessingType {
        get { ProcessingType(rawValue: processingTypeRaw) ?? .speechToText }
        set { processingTypeRaw = newValue.rawValue }
    }
    
    var processingTimeFormatted: String {
        if processingTimeMs < 1000 {
            return "\(processingTimeMs)ms"
        } else {
            return String(format: "%.2fs", Double(processingTimeMs) / 1000.0)
        }
    }
    
    var inputLengthFormatted: String {
        switch processingType {
        case .speechToText, .audioPostProcessing:
            return String(format: "%.1fs", inputLength)
        case .textToSpeech:
            return "\(Int(inputLength)) chars"
        }
    }
    
    var realTimeFactor: Double {
        guard processingType == .speechToText || processingType == .audioPostProcessing else { return 0 }
        guard inputLength > 0 else { return 0 }
        return (Double(processingTimeMs) / 1000.0) / inputLength
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        modelId: UUID? = nil,
        modelName: String,
        processingType: ProcessingType,
        inputLength: Double,
        outputLength: Double,
        processingTimeMs: Int,
        confidence: Double? = nil,
        textContent: String? = nil,
        wasSuccessful: Bool = true,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.modelId = modelId
        self.modelName = modelName
        self.processingTypeRaw = processingType.rawValue
        self.inputLength = inputLength
        self.outputLength = outputLength
        self.processingTimeMs = processingTimeMs
        self.timestamp = Date()
        self.confidence = confidence
        self.textContent = textContent
        self.wasSuccessful = wasSuccessful
        self.errorMessage = errorMessage
    }
}
