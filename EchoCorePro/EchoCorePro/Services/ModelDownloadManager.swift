//
//  ModelDownloadManager.swift
//  EchoCorePro
//
//  Manages model downloads and integrates with SwiftData persistence
//

import Combine
import Foundation
import SwiftData

/// Manages model downloads and tracks them in SwiftData
@MainActor
final class ModelDownloadManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var activeDownloads: [UUID: DownloadProgress] = [:]
    @Published private(set) var isDownloading = false

    // MARK: - Properties

    private let downloadService: DownloadService
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    private let logger = OSLogManager.shared

    /// Default download directory for models
    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let modelsDir = appSupport.appendingPathComponent("EchoCorePro/Models", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        return modelsDir
    }

    // MARK: - Types

    struct DownloadProgress: Identifiable {
        let id: UUID
        let modelName: String
        let modelId: String
        var bytesDownloaded: Int64
        var totalBytes: Int64
        var progress: Double
        var status: DownloadStatus
        var error: String?
        var startTime: Date

        var progressPercent: Int { Int(progress * 100) }

        var eta: TimeInterval? {
            guard progress > 0 else { return nil }
            let elapsed = Date().timeIntervalSince(startTime)
            let totalEstimate = elapsed / progress
            return totalEstimate - elapsed
        }

        var formattedETA: String {
            guard let eta = eta else { return "Calculating..." }
            if eta < 60 {
                return "\(Int(eta))s remaining"
            } else if eta < 3600 {
                return "\(Int(eta / 60))m remaining"
            } else {
                return
                    "\(Int(eta / 3600))h \(Int((eta.truncatingRemainder(dividingBy: 3600)) / 60))m remaining"
            }
        }

        var formattedProgress: String {
            let downloaded = ByteCountFormatter.string(
                fromByteCount: bytesDownloaded, countStyle: .file)
            let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            return "\(downloaded) / \(total)"
        }
    }

    // MARK: - Initialization

    init() {
        self.downloadService = DownloadService()
    }

    /// Set the model context for SwiftData operations
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Download Management

    /// Download a model from the registry
    /// - Parameter model: The available model to download
    func downloadModel(_ model: AvailableModel) async throws {
        logger.log(
            "Starting download for model: \(model.name)", category: .networking, level: .info)

        // Create destination path
        let fileName = "\(model.id.replacingOccurrences(of: "/", with: "_")).bin"
        let destinationPath = modelsDirectory.appendingPathComponent(fileName)

        // Check if already downloaded
        if FileManager.default.fileExists(atPath: destinationPath.path) {
            logger.log(
                "Model already exists at: \(destinationPath.path)", category: .networking,
                level: .info)
            throw DownloadError.alreadyDownloaded
        }

        // Create download job in SwiftData
        let downloadJob = DownloadJobEntity(
            modelName: model.name,
            url: model.downloadURL.absoluteString,
            destinationPath: destinationPath.path
        )

        if let context = modelContext {
            context.insert(downloadJob)
            try? context.save()
        }

        // Start download
        let (downloadId, progressPublisher) = try await downloadService.startDownload(
            url: model.downloadURL,
            destinationPath: destinationPath,
            modelName: model.name
        )

        // Create initial progress
        let initialProgress = DownloadProgress(
            id: downloadId,
            modelName: model.name,
            modelId: model.id,
            bytesDownloaded: 0,
            totalBytes: model.sizeBytes,
            progress: 0,
            status: .downloading,
            startTime: Date()
        )

        activeDownloads[downloadId] = initialProgress
        isDownloading = true

        // Subscribe to progress updates
        progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] serviceProgress in
                guard let self = self else { return }

                // Update our progress
                if var progress = self.activeDownloads[downloadId] {
                    progress.bytesDownloaded = serviceProgress.bytesDownloaded
                    progress.totalBytes =
                        serviceProgress.totalBytes > 0
                        ? serviceProgress.totalBytes : model.sizeBytes
                    progress.progress = serviceProgress.progress
                    progress.status = serviceProgress.status
                    progress.error = serviceProgress.error
                    self.activeDownloads[downloadId] = progress

                    // Update SwiftData job
                    self.updateDownloadJob(
                        modelName: model.name,
                        progress: serviceProgress.progress,
                        bytesDownloaded: serviceProgress.bytesDownloaded,
                        status: serviceProgress.status,
                        error: serviceProgress.error
                    )

                    // Handle completion
                    if serviceProgress.status == .completed {
                        Task {
                            await self.handleDownloadComplete(
                                model: model, destinationPath: destinationPath)
                        }
                    } else if serviceProgress.status == .failed
                        || serviceProgress.status == .cancelled
                    {
                        self.activeDownloads.removeValue(forKey: downloadId)
                        self.isDownloading = !self.activeDownloads.isEmpty
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// Cancel a download
    func cancelDownload(id: UUID) async {
        await downloadService.cancelDownload(id: id)
        activeDownloads.removeValue(forKey: id)
        isDownloading = !activeDownloads.isEmpty
    }

    /// Cancel all downloads
    func cancelAllDownloads() async {
        for id in activeDownloads.keys {
            await downloadService.cancelDownload(id: id)
        }
        activeDownloads.removeAll()
        isDownloading = false
    }

    // MARK: - Private Methods

    private func handleDownloadComplete(model: AvailableModel, destinationPath: URL) async {
        logger.log("Download complete for: \(model.name)", category: .networking, level: .info)

        // Get file size
        let fileSize =
            (try? FileManager.default.attributesOfItem(atPath: destinationPath.path)[.size]
                as? Int64) ?? model.sizeBytes

        // Create LocalModelEntity
        let localModel = LocalModelEntity(
            name: model.name,
            type: model.type,
            version: model.version,
            filePath: destinationPath.path,
            sizeBytes: fileSize
        )
        localModel.huggingFaceId = model.id

        if let context = modelContext {
            context.insert(localModel)

            // Mark download job as completed
            let modelNameToFind = model.name
            let fetchDescriptor = FetchDescriptor<DownloadJobEntity>(
                predicate: #Predicate { $0.modelName == modelNameToFind }
            )
            if let job = try? context.fetch(fetchDescriptor).first {
                job.status = .completed
                job.progress = 1.0
            }

            try? context.save()
        }

        // Remove from active downloads
        for (id, progress) in activeDownloads where progress.modelId == model.id {
            activeDownloads.removeValue(forKey: id)
        }
        isDownloading = !activeDownloads.isEmpty
    }

    private func updateDownloadJob(
        modelName: String,
        progress: Double,
        bytesDownloaded: Int64,
        status: DownloadStatus,
        error: String?
    ) {
        guard let context = modelContext else { return }

        let modelNameToFind = modelName
        let fetchDescriptor = FetchDescriptor<DownloadJobEntity>(
            predicate: #Predicate { $0.modelName == modelNameToFind }
        )

        if let job = try? context.fetch(fetchDescriptor).first {
            job.progress = progress
            job.bytesDownloaded = bytesDownloaded
            job.status = status
            job.errorMessage = error
            try? context.save()
        }
    }

    // MARK: - Model Management

    /// Delete a downloaded model
    func deleteModel(_ model: LocalModelEntity) throws {
        // Delete file
        try FileManager.default.removeItem(atPath: model.filePath)

        // Delete from SwiftData
        if let context = modelContext {
            context.delete(model)
            try context.save()
        }

        logger.log("Deleted model: \(model.name)", category: .storage, level: .info)
    }

    /// Get total size of all downloaded models
    func totalDownloadedSize() -> Int64 {
        guard let context = modelContext else { return 0 }

        let fetchDescriptor = FetchDescriptor<LocalModelEntity>()
        guard let models = try? context.fetch(fetchDescriptor) else { return 0 }

        return models.reduce(0) { $0 + $1.sizeBytes }
    }

    // MARK: - Error Types

    enum DownloadError: Error, LocalizedError {
        case alreadyDownloaded
        case downloadFailed(String)
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .alreadyDownloaded:
                return "This model is already downloaded"
            case .downloadFailed(let reason):
                return "Download failed: \(reason)"
            case .saveFailed(let reason):
                return "Failed to save model: \(reason)"
            }
        }
    }
}
