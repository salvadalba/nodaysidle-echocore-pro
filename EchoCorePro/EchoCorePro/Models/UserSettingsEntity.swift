//
//  UserSettingsEntity.swift
//  EchoCorePro
//
//  SwiftData model for user preferences
//

import Foundation
import SwiftData

/// Preferred language for voice processing
enum PreferredLanguage: String, Codable, CaseIterable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case auto = "auto"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .auto: return "Auto-detect"
        }
    }
}

/// User settings and preferences
@Model
final class UserSettingsEntity {
    /// Singleton ID - always use "settings" as the ID
    @Attribute(.unique) var id: String
    
    /// Default model ID for quick access
    var defaultModelId: UUID?
    
    /// Whether to auto-quantize downloaded models
    var autoQuantize: Bool
    
    /// Memory limit in MB for loaded models
    var memoryLimitMB: Int
    
    /// Whether global hotkeys are enabled
    var hotkeysEnabled: Bool
    
    /// Download location URL as string
    var downloadLocationPath: String
    
    /// Preferred language for processing
    var preferredLanguageRaw: String
    
    /// Audio sample rate for recording
    var audioSampleRate: Int
    
    /// Whether to show waveform visualizer
    var showWaveform: Bool
    
    /// Date settings were last modified
    var lastModified: Date
    
    // MARK: - Computed Properties
    
    var preferredLanguage: PreferredLanguage {
        get { PreferredLanguage(rawValue: preferredLanguageRaw) ?? .auto }
        set { preferredLanguageRaw = newValue.rawValue }
    }
    
    var downloadLocation: URL {
        get { URL(fileURLWithPath: downloadLocationPath) }
        set { downloadLocationPath = newValue.path }
    }
    
    // MARK: - Initialization
    
    init() {
        self.id = "settings"
        self.autoQuantize = false  // Simplified: skip auto-quantization
        self.memoryLimitMB = 2048
        self.hotkeysEnabled = true
        self.audioSampleRate = 16000
        self.showWaveform = true
        self.lastModified = Date()
        self.preferredLanguageRaw = PreferredLanguage.auto.rawValue
        
        // Default download location
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            self.downloadLocationPath = appSupport.appendingPathComponent("EchoCorePro/Models").path
        } else {
            self.downloadLocationPath = "~/Library/Application Support/EchoCorePro/Models"
        }
    }
    
    // MARK: - Factory
    
    static func defaultSettings() -> UserSettingsEntity {
        return UserSettingsEntity()
    }
}
