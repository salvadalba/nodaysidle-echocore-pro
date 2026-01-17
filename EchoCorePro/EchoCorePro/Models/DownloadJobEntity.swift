//
//  DownloadJobEntity.swift
//  EchoCorePro
//
//  SwiftData model for tracking model downloads
//

import Foundation
import SwiftData

/// Status of a download job
enum DownloadStatus: String, Codable, CaseIterable {
    case queued = "Queued"
    case downloading = "Downloading"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
    
    var icon: String {
        switch self {
        case .queued: return "clock"
        case .downloading: return "arrow.down.circle"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .queued: return "gray"
        case .downloading: return "blue"
        case .paused: return "orange"
        case .completed: return "green"
        case .failed: return "red"
        case .cancelled: return "gray"
        }
    }
}

/// Represents a model download job
@Model
final class DownloadJobEntity {
    /// Unique identifier
    @Attribute(.unique) var id: UUID
    
    /// Reference to the model being downloaded
    var modelId: UUID?
    
    /// Model name for display
    var modelName: String
    
    /// Download URL
    var url: String
    
    /// Destination path for the downloaded file
    var destinationPath: String
    
    /// Download progress (0.0 to 1.0)
    var progress: Double
    
    /// Bytes downloaded so far
    var bytesDownloaded: Int64
    
    /// Total bytes to download
    var totalBytes: Int64
    
    /// Current status
    var statusRaw: String
    
    /// Date the download started
    var startDate: Date
    
    /// Date the download was paused (if applicable)
    var pausedDate: Date?
    
    /// Date the download completed (if applicable)
    var completedDate: Date?
    
    /// Error message if failed
    var errorMessage: String?
    
    /// Resume data for paused downloads
    @Attribute(.externalStorage) var resumeData: Data?
    
    // MARK: - Computed Properties
    
    var status: DownloadStatus {
        get { DownloadStatus(rawValue: statusRaw) ?? .queued }
        set { statusRaw = newValue.rawValue }
    }
    
    var progressPercent: Int {
        Int(progress * 100)
    }
    
    var bytesDownloadedFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytesDownloaded)
    }
    
    var totalBytesFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
    
    var estimatedTimeRemaining: TimeInterval? {
        guard status == .downloading, progress > 0 else { return nil }
        let elapsed = Date().timeIntervalSince(startDate)
        let totalEstimated = elapsed / progress
        return totalEstimated - elapsed
    }
    
    var etaFormatted: String? {
        guard let eta = estimatedTimeRemaining else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: eta)
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        modelName: String,
        url: String,
        destinationPath: String,
        status: DownloadStatus = .queued,
        totalBytes: Int64 = 0
    ) {
        self.id = id
        self.modelName = modelName
        self.url = url
        self.destinationPath = destinationPath
        self.progress = 0.0
        self.bytesDownloaded = 0
        self.totalBytes = totalBytes
        self.statusRaw = status.rawValue
        self.startDate = Date()
    }
}
