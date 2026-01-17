//
//  DownloadService.swift
//  EchoCorePro
//
//  Service for downloading voice models from HuggingFace
//

import Foundation
import Combine

/// Service for managing model downloads with progress tracking
actor DownloadService: ServiceProtocol {
    
    // MARK: - ServiceProtocol
    
    nonisolated let serviceId = "DownloadService"
    
    // MARK: - Properties
    
    private let session: URLSession
    private var activeTasks: [UUID: URLSessionDownloadTask] = [:]
    private var progressSubjects: [UUID: CurrentValueSubject<DownloadProgress, Never>] = [:]
    private var progressObservations: [UUID: NSKeyValueObservation] = [:]
    private let logger = OSLogManager.shared
    
    /// Maximum concurrent downloads
    private let maxConcurrentDownloads = 4
    
    /// Allowed download domains (whitelist)
    private let allowedDomains = [
        "huggingface.co",
        "cdn-lfs.huggingface.co",
        "cdn-lfs-us-1.huggingface.co",
        "github.com",
        "raw.githubusercontent.com",
        "objects.githubusercontent.com"
    ]
    
    // MARK: - Types
    
    struct DownloadProgress: Sendable {
        let downloadId: UUID
        var bytesDownloaded: Int64
        var totalBytes: Int64
        var progress: Double
        var status: DownloadStatus
        var error: String?
        
        var progressPercent: Int { Int(progress * 100) }
    }
    
    enum DownloadError: Error, LocalizedError {
        case invalidURL
        case domainNotAllowed(String)
        case downloadFailed(String)
        case checksumMismatch
        case maxDownloadsReached
        case cancelled
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid download URL"
            case .domainNotAllowed(let domain):
                return "Domain not allowed: \(domain). Only HuggingFace and GitHub are supported."
            case .downloadFailed(let reason):
                return "Download failed: \(reason)"
            case .checksumMismatch:
                return "File checksum does not match expected value"
            case .maxDownloadsReached:
                return "Maximum concurrent downloads reached"
            case .cancelled:
                return "Download was cancelled"
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = maxConcurrentDownloads
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600 // 1 hour max for large models
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - ServiceProtocol Implementation
    
    func initialize() async throws {
        logger.log("DownloadService initialized", category: .networking, level: .info)
    }
    
    func shutdown() async {
        // Cancel all active downloads
        for (id, task) in activeTasks {
            task.cancel()
            logger.log("Cancelled download: \(id)", category: .networking, level: .debug)
        }
        activeTasks.removeAll()
        progressSubjects.removeAll()
        progressObservations.removeAll()
        logger.log("DownloadService shutdown", category: .networking, level: .info)
    }
    
    // MARK: - Download Management
    
    /// Start downloading a model from URL
    /// - Parameters:
    ///   - url: The URL to download from
    ///   - destinationPath: Local path to save the file
    ///   - modelName: Name for logging and display
    /// - Returns: Download ID and progress publisher
    func startDownload(
        url: URL,
        destinationPath: URL,
        modelName: String
    ) async throws -> (UUID, AnyPublisher<DownloadProgress, Never>) {
        
        // Validate domain
        guard let host = url.host else {
            throw DownloadError.invalidURL
        }
        
        guard allowedDomains.contains(where: { host.contains($0) }) else {
            throw DownloadError.domainNotAllowed(host)
        }
        
        // Check concurrent downloads
        guard activeTasks.count < maxConcurrentDownloads else {
            throw DownloadError.maxDownloadsReached
        }
        
        let downloadId = UUID()
        logger.log("Starting download: \(modelName) from \(url)", category: .networking, level: .info)
        
        // Create progress subject
        let progressSubject = CurrentValueSubject<DownloadProgress, Never>(
            DownloadProgress(
                downloadId: downloadId,
                bytesDownloaded: 0,
                totalBytes: 0,
                progress: 0,
                status: .downloading
            )
        )
        progressSubjects[downloadId] = progressSubject
        
        // Create download task
        let task = session.downloadTask(with: url) { [weak self] tempURL, response, error in
            Task {
                await self?.handleDownloadCompletion(
                    downloadId: downloadId,
                    tempURL: tempURL,
                    destinationPath: destinationPath,
                    response: response,
                    error: error
                )
            }
        }
        
        // Observe progress and store the observation
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task {
                await self?.updateProgress(
                    downloadId: downloadId,
                    bytesDownloaded: task.countOfBytesReceived,
                    totalBytes: task.countOfBytesExpectedToReceive,
                    progress: progress.fractionCompleted
                )
            }
        }
        progressObservations[downloadId] = observation
        
        // Store and start
        activeTasks[downloadId] = task
        task.resume()
        
        return (downloadId, progressSubject.eraseToAnyPublisher())
    }
    
    /// Pause a download
    func pauseDownload(id: UUID) async throws -> Data? {
        guard let task = activeTasks[id] else { return nil }
        
        return await withCheckedContinuation { continuation in
            task.cancel { resumeData in
                continuation.resume(returning: resumeData)
            }
        }
    }
    
    /// Resume a paused download
    func resumeDownload(id: UUID, resumeData: Data, destinationPath: URL) async throws {
        let task = session.downloadTask(withResumeData: resumeData) { [weak self] tempURL, response, error in
            Task {
                await self?.handleDownloadCompletion(
                    downloadId: id,
                    tempURL: tempURL,
                    destinationPath: destinationPath,
                    response: response,
                    error: error
                )
            }
        }
        
        activeTasks[id] = task
        task.resume()
        
        logger.log("Resumed download: \(id)", category: .networking, level: .info)
    }
    
    /// Cancel a download
    func cancelDownload(id: UUID) async {
        if let task = activeTasks[id] {
            task.cancel()
            activeTasks.removeValue(forKey: id)
            progressObservations.removeValue(forKey: id)
            
            if let subject = progressSubjects[id] {
                var progress = subject.value
                progress.status = .cancelled
                subject.send(progress)
                subject.send(completion: .finished)
            }
            progressSubjects.removeValue(forKey: id)
            
            logger.log("Cancelled download: \(id)", category: .networking, level: .info)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateProgress(downloadId: UUID, bytesDownloaded: Int64, totalBytes: Int64, progress: Double) {
        guard let subject = progressSubjects[downloadId] else { return }
        
        var update = subject.value
        update.bytesDownloaded = bytesDownloaded
        update.totalBytes = totalBytes
        update.progress = progress
        subject.send(update)
    }
    
    private func handleDownloadCompletion(
        downloadId: UUID,
        tempURL: URL?,
        destinationPath: URL,
        response: URLResponse?,
        error: Error?
    ) {
        activeTasks.removeValue(forKey: downloadId)
        progressObservations.removeValue(forKey: downloadId)
        
        guard let subject = progressSubjects[downloadId] else { return }
        var progress = subject.value
        
        if let error = error as? NSError {
            if error.code == NSURLErrorCancelled {
                progress.status = .cancelled
            } else {
                progress.status = .failed
                progress.error = error.localizedDescription
            }
            logger.log("Download failed: \(error.localizedDescription)", category: .networking, level: .error)
        } else if let tempURL = tempURL {
            // Move file to destination
            do {
                // Create directory if needed
                try FileManager.default.createDirectory(
                    at: destinationPath.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationPath.path) {
                    try FileManager.default.removeItem(at: destinationPath)
                }
                
                // Move downloaded file
                try FileManager.default.moveItem(at: tempURL, to: destinationPath)
                
                progress.status = .completed
                progress.progress = 1.0
                logger.log("Download completed: \(destinationPath.lastPathComponent)", category: .networking, level: .info)
            } catch {
                progress.status = .failed
                progress.error = error.localizedDescription
                logger.log("Failed to save download: \(error.localizedDescription)", category: .networking, level: .error)
            }
        } else {
            progress.status = .failed
            progress.error = "Unknown error"
        }
        
        subject.send(progress)
        subject.send(completion: .finished)
        progressSubjects.removeValue(forKey: downloadId)
    }
    
    // MARK: - Utility
    
    /// Verify file checksum
    func verifyChecksum(fileURL: URL, expectedSHA256: String) async throws -> Bool {
        logger.log("Verifying checksum for: \(fileURL.lastPathComponent)", category: .networking, level: .debug)
        
        // TODO: Implement SHA-256 verification
        // For now, return true
        return true
    }
    
    /// Get active download count
    var activeDownloadCount: Int {
        activeTasks.count
    }
}
