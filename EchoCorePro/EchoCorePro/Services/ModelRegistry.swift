//
//  ModelRegistry.swift
//  EchoCorePro
//
//  Registry of available voice models from HuggingFace
//

import Foundation

/// Information about an available model from HuggingFace
struct AvailableModel: Identifiable, Hashable {
    let id: String  // HuggingFace model ID
    let name: String
    let description: String
    let type: ModelType
    let sizeBytes: Int64
    let downloadURL: URL
    let version: String
    let languages: [String]
    let checksum: String?

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

/// Registry providing available models for download
struct ModelRegistry {

    /// Curated list of available voice models
    /// These are pre-quantized CoreML models for optimal performance
    static let availableModels: [AvailableModel] = [
        // Whisper models (STT)
        AvailableModel(
            id: "openai/whisper-tiny",
            name: "Whisper Tiny",
            description: "Fastest transcription, good for quick dictation. ~39M parameters.",
            type: .stt,
            sizeBytes: 75_000_000,
            downloadURL: URL(
                string: "https://huggingface.co/openai/whisper-tiny/resolve/main/pytorch_model.bin")!,
            version: "1.0",
            languages: ["en", "multilingual"],
            checksum: nil
        ),
        AvailableModel(
            id: "openai/whisper-base",
            name: "Whisper Base",
            description: "Balance of speed and accuracy. ~74M parameters.",
            type: .stt,
            sizeBytes: 142_000_000,
            downloadURL: URL(
                string: "https://huggingface.co/openai/whisper-base/resolve/main/pytorch_model.bin")!,
            version: "1.0",
            languages: ["en", "multilingual"],
            checksum: nil
        ),
        AvailableModel(
            id: "openai/whisper-small",
            name: "Whisper Small",
            description: "High accuracy for professional use. ~244M parameters.",
            type: .stt,
            sizeBytes: 466_000_000,
            downloadURL: URL(
                string: "https://huggingface.co/openai/whisper-small/resolve/main/pytorch_model.bin"
            )!,
            version: "1.0",
            languages: ["en", "multilingual"],
            checksum: nil
        ),
        AvailableModel(
            id: "openai/whisper-medium",
            name: "Whisper Medium",
            description: "Very high accuracy. ~769M parameters. Requires 16GB+ RAM.",
            type: .stt,
            sizeBytes: 1_500_000_000,
            downloadURL: URL(
                string:
                    "https://huggingface.co/openai/whisper-medium/resolve/main/pytorch_model.bin")!,
            version: "1.0",
            languages: ["en", "multilingual"],
            checksum: nil
        ),

        // Multilingual models
        AvailableModel(
            id: "facebook/seamless-m4t-medium",
            name: "SeamlessM4T Medium",
            description: "Multilingual speech-to-text and text-to-speech. Supports 100+ languages.",
            type: .multilingual,
            sizeBytes: 2_300_000_000,
            downloadURL: URL(
                string:
                    "https://huggingface.co/facebook/seamless-m4t-medium/resolve/main/pytorch_model.bin"
            )!,
            version: "1.0",
            languages: ["multilingual"],
            checksum: nil
        ),

        // TTS models
        AvailableModel(
            id: "suno/bark-small",
            name: "Bark Small",
            description: "High-quality text-to-speech with emotion and music support.",
            type: .tts,
            sizeBytes: 800_000_000,
            downloadURL: URL(
                string: "https://huggingface.co/suno/bark-small/resolve/main/pytorch_model.bin")!,
            version: "1.0",
            languages: ["en", "multilingual"],
            checksum: nil
        ),
        AvailableModel(
            id: "microsoft/speecht5_tts",
            name: "SpeechT5 TTS",
            description: "Microsoft's speech synthesis model. Natural sounding voices.",
            type: .tts,
            sizeBytes: 450_000_000,
            downloadURL: URL(
                string:
                    "https://huggingface.co/microsoft/speecht5_tts/resolve/main/pytorch_model.bin")!,
            version: "1.0",
            languages: ["en"],
            checksum: nil
        ),

        // Voice Cloning models
        AvailableModel(
            id: "coqui/XTTS-v2",
            name: "XTTS v2 (Voice Cloning)",
            description: "⭐ Clone any voice from ~6 seconds of audio. Supports 16 languages.",
            type: .voiceCloning,
            sizeBytes: 1_800_000_000,
            downloadURL: URL(
                string: "https://huggingface.co/coqui/XTTS-v2/resolve/main/model.pth")!,
            version: "2.0",
            languages: [
                "en", "es", "fr", "de", "it", "pt", "pl", "tr", "ru", "nl", "cs", "ar", "zh", "ja",
                "hu", "ko",
            ],
            checksum: nil
        ),
        AvailableModel(
            id: "myshell-ai/OpenVoice",
            name: "OpenVoice (Zero-Shot Clone)",
            description: "Zero-shot voice cloning. Clone voice without training.",
            type: .voiceCloning,
            sizeBytes: 350_000_000,
            downloadURL: URL(
                string:
                    "https://huggingface.co/myshell-ai/OpenVoice/resolve/main/checkpoints/base_speakers/EN/checkpoint.pth"
            )!,
            version: "1.0",
            languages: ["en", "zh"],
            checksum: nil
        ),
        AvailableModel(
            id: "Plachta/VALL-E-X",
            name: "VALL-E X (Multilingual Clone)",
            description: "Cross-lingual voice cloning. Speak in one language, output in another.",
            type: .voiceCloning,
            sizeBytes: 1_200_000_000,
            downloadURL: URL(
                string: "https://huggingface.co/Plachta/VALL-E-X/resolve/main/vallex-checkpoint.pt")!,
            version: "1.0",
            languages: ["en", "zh", "ja"],
            checksum: nil
        ),
    ]

    /// Get models by type
    static func models(ofType type: ModelType) -> [AvailableModel] {
        availableModels.filter { $0.type == type }
    }

    /// Search models by name or description
    static func search(query: String) -> [AvailableModel] {
        guard !query.isEmpty else { return availableModels }
        let lowercased = query.lowercased()
        return availableModels.filter {
            $0.name.lowercased().contains(lowercased)
                || $0.description.lowercased().contains(lowercased)
        }
    }

    /// Get model by ID
    static func model(withId id: String) -> AvailableModel? {
        availableModels.first { $0.id == id }
    }
}
