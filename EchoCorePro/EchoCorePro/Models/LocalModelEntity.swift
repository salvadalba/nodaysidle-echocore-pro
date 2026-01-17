//
//  LocalModelEntity.swift
//  EchoCorePro
//
//  SwiftData model for locally stored voice models
//

import Foundation
import SwiftData

/// Type of voice model
enum ModelType: String, Codable, CaseIterable {
    case stt = "Speech to Text"
    case tts = "Text to Speech"
    case voiceCloning = "Voice Cloning"
    case multilingual = "Multilingual"
    case embedding = "Embedding"

    var icon: String {
        switch self {
        case .stt: return "mic.fill"
        case .tts: return "speaker.wave.3.fill"
        case .voiceCloning: return "person.wave.2.fill"
        case .multilingual: return "globe"
        case .embedding: return "brain"
        }
    }
}

/// Quantization type for model optimization
enum QuantizationType: String, Codable, CaseIterable {
    case int4 = "INT4"
    case int8 = "INT8"
    case fp16 = "FP16"
    case none = "None"

    var description: String {
        switch self {
        case .int4: return "4-bit Integer (smallest, fastest)"
        case .int8: return "8-bit Integer (balanced)"
        case .fp16: return "16-bit Float (highest quality)"
        case .none: return "Original (largest)"
        }
    }
}

/// Represents a locally stored voice model
@Model
final class LocalModelEntity {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Display name of the model
    var name: String

    /// Model type (STT, TTS, etc.)
    var typeRaw: String

    /// Model version string
    var version: String

    /// Local file path to the model
    var filePath: String

    /// Model size in bytes
    var sizeBytes: Int64

    /// Whether the model has been quantized
    var isQuantized: Bool

    /// Type of quantization applied
    var quantizationTypeRaw: String?

    /// Date the model was downloaded
    var dateDownloaded: Date

    /// Last time the model was used
    var lastUsed: Date?

    /// HuggingFace model ID for updates
    var huggingFaceId: String?

    /// SHA-256 checksum for verification
    var checksum: String?

    /// Whether the model is currently loaded in memory
    @Transient var isLoaded: Bool = false

    /// Memory usage when loaded (MB)
    @Transient var memoryUsageMB: Int = 0

    // MARK: - Computed Properties

    var type: ModelType {
        get { ModelType(rawValue: typeRaw) ?? .stt }
        set { typeRaw = newValue.rawValue }
    }

    var quantizationType: QuantizationType? {
        get { quantizationTypeRaw.flatMap { QuantizationType(rawValue: $0) } }
        set { quantizationTypeRaw = newValue?.rawValue }
    }

    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        type: ModelType,
        version: String,
        filePath: String,
        sizeBytes: Int64,
        isQuantized: Bool = false,
        quantizationType: QuantizationType? = nil,
        dateDownloaded: Date = Date(),
        huggingFaceId: String? = nil,
        checksum: String? = nil
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.version = version
        self.filePath = filePath
        self.sizeBytes = sizeBytes
        self.isQuantized = isQuantized
        self.quantizationTypeRaw = quantizationType?.rawValue
        self.dateDownloaded = dateDownloaded
        self.huggingFaceId = huggingFaceId
        self.checksum = checksum
    }
}
