//
//  AppProtocol.swift
//  EchoCorePro
//
//  Protocol defining core application lifecycle methods
//

import Foundation

/// Error types for application lifecycle operations
enum AppError: Error, LocalizedError {
    case initializationFailed(reason: String)
    case serviceFailed(service: String, reason: String)
    case resourceUnavailable(resource: String)
    case modelLoadFailed(modelId: String, reason: String)
    case networkError(reason: String)
    case processingFailed(reason: String)
    case permissionDenied(permission: String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let reason):
            return "Initialization failed: \(reason)"
        case .serviceFailed(let service, let reason):
            return "Service '\(service)' failed: \(reason)"
        case .resourceUnavailable(let resource):
            return "Resource unavailable: \(resource)"
        case .modelLoadFailed(let modelId, let reason):
            return "Failed to load model '\(modelId)': \(reason)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

/// Protocol defining core application lifecycle methods
@MainActor
protocol AppProtocol: AnyObject {
    /// Initialize and start the application
    func main() async throws
    
    /// Gracefully shutdown the application
    func shutdown() async
    
    /// Handle application errors with appropriate recovery or logging
    /// - Parameter error: The error that occurred
    func handleError(_ error: AppError)
    
    /// Service registry for dependency injection
    var serviceRegistry: ServiceRegistry { get }
    
    /// View model registry for UI state management
    var viewModelRegistry: ViewModelRegistry { get }
}
