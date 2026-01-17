//
//  ViewModelRegistry.swift
//  EchoCorePro
//
//  Registry providing view models to SwiftUI views with dependency injection
//

import Foundation
import Combine

/// Registry for providing view models to views
/// Manages view model lifecycle and dependencies
@MainActor
final class ViewModelRegistry: ObservableObject {
    
    // MARK: - Dependencies
    
    private let serviceRegistry: ServiceRegistry
    private let logger = OSLogManager.shared
    
    // MARK: - Cached View Models
    
    /// Cached view models for reuse
    private var viewModels: [String: any ObservableObject] = [:]
    
    // MARK: - Initialization
    
    init(serviceRegistry: ServiceRegistry) {
        self.serviceRegistry = serviceRegistry
        logger.log("ViewModelRegistry created", category: .lifecycle, level: .debug)
    }
    
    // MARK: - View Model Providers
    
    /// Get or create a ModelListViewModel
    func modelListViewModel() -> ModelListViewModel {
        return getOrCreate(ModelListViewModel.self) {
            ModelListViewModel(serviceRegistry: self.serviceRegistry)
        }
    }
    
    /// Get or create a DownloadViewModel
    func downloadViewModel() -> DownloadViewModel {
        return getOrCreate(DownloadViewModel.self) {
            DownloadViewModel(serviceRegistry: self.serviceRegistry)
        }
    }
    
    /// Get or create an InferenceViewModel
    func inferenceViewModel() -> InferenceViewModel {
        return getOrCreate(InferenceViewModel.self) {
            InferenceViewModel(serviceRegistry: self.serviceRegistry)
        }
    }
    
    /// Get or create a SettingsViewModel
    func settingsViewModel() -> SettingsViewModel {
        return getOrCreate(SettingsViewModel.self) {
            SettingsViewModel(serviceRegistry: self.serviceRegistry)
        }
    }
    
    // MARK: - Private Helpers
    
    /// Get an existing view model or create a new one
    private func getOrCreate<T: ObservableObject>(_ type: T.Type, factory: () -> T) -> T {
        let key = String(describing: type)
        
        if let existing = viewModels[key] as? T {
            return existing
        }
        
        let newViewModel = factory()
        viewModels[key] = newViewModel
        logger.log("Created view model: \(key)", category: .lifecycle, level: .debug)
        return newViewModel
    }
    
    /// Clear all cached view models
    func clearAll() {
        viewModels.removeAll()
        logger.log("Cleared all view models", category: .lifecycle, level: .debug)
    }
}

// MARK: - Placeholder View Models

/// View model for model list management
@MainActor
final class ModelListViewModel: ObservableObject {
    @Published var models: [ModelItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let serviceRegistry: ServiceRegistry
    
    init(serviceRegistry: ServiceRegistry) {
        self.serviceRegistry = serviceRegistry
    }
    
    func loadModels() async {
        isLoading = true
        // TODO: Load models from repository
        isLoading = false
    }
}

/// View model for download management
@MainActor
final class DownloadViewModel: ObservableObject {
    @Published var downloads: [DownloadItem] = []
    @Published var isDownloading: Bool = false
    
    private let serviceRegistry: ServiceRegistry
    
    init(serviceRegistry: ServiceRegistry) {
        self.serviceRegistry = serviceRegistry
    }
    
    func startDownload(modelId: String) async {
        // TODO: Start download
    }
    
    func pauseDownload(downloadId: UUID) async {
        // TODO: Pause download
    }
    
    func resumeDownload(downloadId: UUID) async {
        // TODO: Resume download
    }
}

/// View model for inference operations
@MainActor
final class InferenceViewModel: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var transcribedText: String = ""
    @Published var synthesizedAudioURL: URL?
    @Published var confidence: Double = 0.0
    
    private let serviceRegistry: ServiceRegistry
    
    init(serviceRegistry: ServiceRegistry) {
        self.serviceRegistry = serviceRegistry
    }
    
    func startRecording() {
        // TODO: Start recording
        isRecording = true
    }
    
    func stopRecording() async -> String {
        // TODO: Stop recording and transcribe
        isRecording = false
        return transcribedText
    }
    
    func synthesizeSpeech(text: String) async {
        // TODO: TTS synthesis
    }
}

/// View model for settings
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var defaultModelId: UUID?
    @Published var autoQuantize: Bool = true
    @Published var memoryLimitMB: Int = 2048
    @Published var hotkeysEnabled: Bool = true
    @Published var downloadLocation: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    
    private let serviceRegistry: ServiceRegistry
    
    init(serviceRegistry: ServiceRegistry) {
        self.serviceRegistry = serviceRegistry
        loadSettings()
    }
    
    func loadSettings() {
        // TODO: Load from SwiftData
    }
    
    func saveSettings() async {
        // TODO: Save to SwiftData
    }
    
    func resetToDefaults() {
        autoQuantize = true
        memoryLimitMB = 2048
        hotkeysEnabled = true
    }
}

// MARK: - Placeholder Data Types

/// Represents a model item in the UI
struct ModelItem: Identifiable {
    let id: UUID
    let name: String
    let type: String
    let sizeBytes: Int64
    let isQuantized: Bool
    let isLoaded: Bool
}

/// Represents a download item in the UI
struct DownloadItem: Identifiable {
    let id: UUID
    let modelName: String
    var progress: Double
    var status: String
    var bytesDownloaded: Int64
    var totalBytes: Int64
}
