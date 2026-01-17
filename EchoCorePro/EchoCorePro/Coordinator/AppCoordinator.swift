//
//  AppCoordinator.swift
//  EchoCorePro
//
//  Core application coordinator managing lifecycle and dependencies
//

import Foundation
import SwiftUI
import Combine

/// Main application coordinator conforming to AppProtocol
/// Manages application lifecycle, dependency injection, and error handling
@MainActor
final class AppCoordinator: ObservableObject, AppProtocol {
    
    // MARK: - Published Properties
    
    /// Current application state
    @Published private(set) var appState: AppState = .initializing
    
    /// Current error if any
    @Published private(set) var currentError: AppError?
    
    /// Whether the app is ready for use
    @Published private(set) var isReady: Bool = false
    
    // MARK: - Registries
    
    /// Service registry for dependency injection
    let serviceRegistry: ServiceRegistry
    
    /// View model registry for UI state management
    let viewModelRegistry: ViewModelRegistry
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let logger = OSLogManager.shared
    
    // MARK: - Application States
    
    enum AppState: Equatable {
        case initializing
        case ready
        case processing
        case error(String)
        case shuttingDown
    }
    
    // MARK: - Initialization
    
    init() {
        // Initialize registries
        self.serviceRegistry = ServiceRegistry()
        self.viewModelRegistry = ViewModelRegistry(serviceRegistry: serviceRegistry)
        
        logger.log("AppCoordinator initializing", category: .lifecycle, level: .info)
        
        // Start async initialization
        Task {
            do {
                try await main()
            } catch {
                handleError(.initializationFailed(reason: error.localizedDescription))
            }
        }
    }
    
    // MARK: - AppProtocol Implementation
    
    func main() async throws {
        logger.log("Starting EchoCorePro main initialization", category: .lifecycle, level: .info)
        
        appState = .initializing
        
        // Initialize all services
        do {
            try await initializeServices()
        } catch {
            throw AppError.initializationFailed(reason: error.localizedDescription)
        }
        
        // Setup observers for service health
        setupObservers()
        
        // Mark as ready
        appState = .ready
        isReady = true
        
        logger.log("EchoCorePro initialization complete", category: .lifecycle, level: .info)
    }
    
    func shutdown() async {
        logger.log("Shutting down EchoCorePro", category: .lifecycle, level: .info)
        
        appState = .shuttingDown
        
        // Cancel all subscriptions
        cancellables.removeAll()
        
        // Shutdown services in reverse order
        await serviceRegistry.shutdownAll()
        
        // Flush logs
        logger.flush()
        
        logger.log("EchoCorePro shutdown complete", category: .lifecycle, level: .info)
    }
    
    func handleError(_ error: AppError) {
        logger.log("Error occurred: \(error.localizedDescription)",
                  category: .lifecycle,
                  level: .error)
        
        currentError = error
        
        // Update state if critical
        switch error {
        case .initializationFailed, .serviceFailed:
            appState = .error(error.localizedDescription)
        default:
            // Non-critical errors don't change app state
            break
        }
        
        // Show alert to user for critical errors
        if case .initializationFailed = error {
            showErrorAlert(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeServices() async throws {
        logger.log("Initializing services", category: .lifecycle, level: .debug)
        
        // Initialize in dependency order
        // 1. Core services (logging already initialized)
        // 2. Data layer services
        // 3. Network services
        // 4. Inference services
        // 5. UI services
        
        // Register all services with the registry
        await serviceRegistry.registerCoreServices()
        
        logger.log("All services initialized", category: .lifecycle, level: .debug)
    }
    
    private func setupObservers() {
        // Observe application lifecycle
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.shutdown()
                }
            }
            .store(in: &cancellables)
        
        // Observe memory warnings
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.logger.log("Application became active", category: .lifecycle, level: .debug)
            }
            .store(in: &cancellables)
    }
    
    private func showErrorAlert(_ error: AppError) {
        let alert = NSAlert()
        alert.messageText = "EchoCore Pro Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Public Action Methods
    
    /// Clear the current error state
    func clearError() {
        currentError = nil
        if case .error = appState {
            appState = .ready
        }
    }
}

// MARK: - Environment Keys

/// Environment key for ServiceRegistry
private struct ServiceRegistryKey: EnvironmentKey {
    static let defaultValue: ServiceRegistry? = nil
}

/// Environment key for ViewModelRegistry
private struct ViewModelRegistryKey: EnvironmentKey {
    static let defaultValue: ViewModelRegistry? = nil
}

extension EnvironmentValues {
    var serviceRegistry: ServiceRegistry? {
        get { self[ServiceRegistryKey.self] }
        set { self[ServiceRegistryKey.self] = newValue }
    }
    
    var viewModelRegistry: ViewModelRegistry? {
        get { self[ViewModelRegistryKey.self] }
        set { self[ViewModelRegistryKey.self] = newValue }
    }
}
