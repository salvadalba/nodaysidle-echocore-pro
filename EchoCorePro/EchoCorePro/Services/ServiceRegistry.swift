//
//  ServiceRegistry.swift
//  EchoCorePro
//
//  Dependency injection container for all application services
//

import Foundation
import Combine

/// Service lifecycle protocol
protocol ServiceProtocol: AnyObject, Sendable {
    /// Unique identifier for the service
    var serviceId: String { get }
    
    /// Initialize the service
    func initialize() async throws
    
    /// Shutdown the service gracefully
    func shutdown() async
}

/// Base service class providing common functionality
class BaseService: ServiceProtocol, @unchecked Sendable {
    let serviceId: String
    
    init(serviceId: String) {
        self.serviceId = serviceId
    }
    
    func initialize() async throws {
        OSLogManager.shared.log("Service \(serviceId) initialized", category: .lifecycle, level: .debug)
    }
    
    func shutdown() async {
        OSLogManager.shared.log("Service \(serviceId) shutdown", category: .lifecycle, level: .debug)
    }
}

/// Central registry for all application services
/// Provides dependency injection and lifecycle management
@MainActor
final class ServiceRegistry: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isInitialized: Bool = false
    
    // MARK: - Private Storage
    
    private var services: [String: any ServiceProtocol] = [:]
    private var initializationOrder: [String] = []
    private let logger = OSLogManager.shared
    
    // MARK: - Initialization
    
    init() {
        logger.log("ServiceRegistry created", category: .lifecycle, level: .debug)
    }
    
    // MARK: - Service Registration
    
    /// Register a service with the registry
    /// - Parameter service: The service to register
    func register<T: ServiceProtocol>(_ service: T) {
        let id = service.serviceId
        services[id] = service
        initializationOrder.append(id)
        logger.log("Registered service: \(id)", category: .lifecycle, level: .debug)
    }
    
    /// Get a service by type
    /// - Returns: The service if found, nil otherwise
    func resolve<T: ServiceProtocol>(_ type: T.Type) -> T? {
        for service in services.values {
            if let typedService = service as? T {
                return typedService
            }
        }
        return nil
    }
    
    /// Get a service by identifier
    /// - Parameter serviceId: The service identifier
    /// - Returns: The service if found, nil otherwise
    func resolve(byId serviceId: String) -> (any ServiceProtocol)? {
        return services[serviceId]
    }
    
    // MARK: - Lifecycle Management
    
    /// Register and initialize all core services
    func registerCoreServices() async {
        logger.log("Registering core services", category: .lifecycle, level: .info)
        
        // Services will be registered here as they are implemented
        // For now, just mark as initialized
        
        isInitialized = true
        logger.log("Core services registered", category: .lifecycle, level: .info)
    }
    
    /// Initialize all registered services in order
    func initializeAll() async throws {
        logger.log("Initializing all services", category: .lifecycle, level: .info)
        
        for serviceId in initializationOrder {
            guard let service = services[serviceId] else { continue }
            
            do {
                try await service.initialize()
                logger.log("Service \(serviceId) initialized successfully", category: .lifecycle, level: .debug)
            } catch {
                logger.log("Service \(serviceId) failed to initialize: \(error)", category: .lifecycle, level: .error)
                throw error
            }
        }
        
        isInitialized = true
        logger.log("All services initialized", category: .lifecycle, level: .info)
    }
    
    /// Shutdown all services in reverse order
    func shutdownAll() async {
        logger.log("Shutting down all services", category: .lifecycle, level: .info)
        
        // Shutdown in reverse order
        for serviceId in initializationOrder.reversed() {
            guard let service = services[serviceId] else { continue }
            await service.shutdown()
            logger.log("Service \(serviceId) shutdown", category: .lifecycle, level: .debug)
        }
        
        isInitialized = false
        logger.log("All services shutdown", category: .lifecycle, level: .info)
    }
}

// MARK: - Placeholder Services (to be implemented)

/// Placeholder for ModelDownloadService
final class ModelDownloadServicePlaceholder: BaseService, @unchecked Sendable {
    init() {
        super.init(serviceId: "ModelDownloadService")
    }
}

/// Placeholder for QuantizationService
final class QuantizationServicePlaceholder: BaseService, @unchecked Sendable {
    init() {
        super.init(serviceId: "QuantizationService")
    }
}

/// Placeholder for InferenceEngine
final class InferenceEnginePlaceholder: BaseService, @unchecked Sendable {
    init() {
        super.init(serviceId: "InferenceEngine")
    }
}

/// Placeholder for AudioProcessingPipeline
final class AudioProcessingPipelinePlaceholder: BaseService, @unchecked Sendable {
    init() {
        super.init(serviceId: "AudioProcessingPipeline")
    }
}

/// Placeholder for HotkeyService
final class HotkeyServicePlaceholder: BaseService, @unchecked Sendable {
    init() {
        super.init(serviceId: "HotkeyService")
    }
}

/// Placeholder for LocalHTTPServer
final class LocalHTTPServerPlaceholder: BaseService, @unchecked Sendable {
    init() {
        super.init(serviceId: "LocalHTTPServer")
    }
}

