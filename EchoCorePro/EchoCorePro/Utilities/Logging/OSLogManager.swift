//
//  OSLogManager.swift
//  EchoCorePro
//
//  Centralized logging system with file persistence
//

import Foundation
import OSLog

/// Log categories for different subsystems
enum LogCategory: String, CaseIterable {
    case networking = "networking"
    case inference = "inference"
    case metal = "metal"
    case storage = "storage"
    case lifecycle = "lifecycle"
    
    var osLogCategory: String {
        return rawValue
    }
}

/// Log levels
enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🔥"
        }
    }
}

/// Centralized logging manager with OSLog and file persistence
final class OSLogManager: @unchecked Sendable {
    
    // MARK: - Singleton
    
    static let shared = OSLogManager()
    
    // MARK: - Constants
    
    private let subsystem = "com.echocore.pro"
    private let logDirectoryName = "EchoCorePro"
    private let retentionDays = 30
    private let maxLogFileSizeMB = 50
    
    // MARK: - Properties
    
    private var loggers: [LogCategory: Logger] = [:]
    private let fileManager = FileManager.default
    private var logFileURL: URL?
    private let queue = DispatchQueue(label: "com.echocore.pro.logging", qos: .utility)
    private var logFileHandle: FileHandle?
    
    /// Minimum log level for file logging (debug in DEBUG, info in RELEASE)
    private let minimumFileLogLevel: LogLevel
    
    // MARK: - Initialization
    
    private init() {
        #if DEBUG
        minimumFileLogLevel = .debug
        #else
        minimumFileLogLevel = .info
        #endif
        
        // Create loggers for each category
        for category in LogCategory.allCases {
            loggers[category] = Logger(subsystem: subsystem, category: category.osLogCategory)
        }
        
        // Setup file logging
        setupFileLogging()
        
        // Clean old logs
        cleanOldLogs()
    }
    
    deinit {
        try? logFileHandle?.close()
    }
    
    // MARK: - Public Logging Methods
    
    /// Log a message with the specified category and level
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - level: The log level
    func log(_ message: String, category: LogCategory, level: LogLevel) {
        guard let logger = loggers[category] else { return }
        
        // Log to OSLog
        switch level {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        case .critical:
            logger.critical("\(message)")
        }
        
        // Log to file if above threshold
        if level >= minimumFileLogLevel {
            writeToFile(message, category: category, level: level)
        }
    }
    
    /// Log with formatting support
    func log(_ message: String, category: LogCategory, level: LogLevel, metadata: [String: Any]? = nil) {
        var fullMessage = message
        if let metadata = metadata, !metadata.isEmpty {
            let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            fullMessage += " [\(metadataString)]"
        }
        log(fullMessage, category: category, level: level)
    }
    
    /// Flush any buffered logs to disk
    func flush() {
        queue.sync {
            try? logFileHandle?.synchronize()
        }
    }
    
    // MARK: - File Logging
    
    private func setupFileLogging() {
        guard let logsDirectory = getLogsDirectory() else {
            print("Failed to create logs directory")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let logFileName = "echocore-\(dateString).log"
        logFileURL = logsDirectory.appendingPathComponent(logFileName)
        
        guard let logFileURL = logFileURL else { return }
        
        // Create file if it doesn't exist
        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
        }
        
        // Open file handle for appending
        do {
            logFileHandle = try FileHandle(forWritingTo: logFileURL)
            try logFileHandle?.seekToEnd()
            
            // Write startup marker
            let startupMessage = "\n========== EchoCorePro Log Started at \(Date()) ==========\n"
            if let data = startupMessage.data(using: .utf8) {
                try logFileHandle?.write(contentsOf: data)
            }
        } catch {
            print("Failed to open log file: \(error)")
        }
    }
    
    private func getLogsDirectory() -> URL? {
        guard let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let logsURL = libraryURL.appendingPathComponent("Logs").appendingPathComponent(logDirectoryName)
        
        if !fileManager.fileExists(atPath: logsURL.path) {
            do {
                try fileManager.createDirectory(at: logsURL, withIntermediateDirectories: true)
            } catch {
                print("Failed to create logs directory: \(error)")
                return nil
            }
        }
        
        return logsURL
    }
    
    private func writeToFile(_ message: String, category: LogCategory, level: LogLevel) {
        queue.async { [weak self] in
            guard let self = self, let fileHandle = self.logFileHandle else { return }
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let timestamp = dateFormatter.string(from: Date())
            
            let logLine = "\(timestamp) \(level.emoji) [\(category.rawValue.uppercased())] \(message)\n"
            
            if let data = logLine.data(using: .utf8) {
                do {
                    try fileHandle.write(contentsOf: data)
                } catch {
                    // Silently fail file writes to avoid log spam
                }
            }
        }
    }
    
    // MARK: - Log Retention
    
    private func cleanOldLogs() {
        queue.async { [weak self] in
            guard let self = self, let logsDirectory = self.getLogsDirectory() else { return }
            
            let calendar = Calendar.current
            let cutoffDate = calendar.date(byAdding: .day, value: -self.retentionDays, to: Date())!
            
            do {
                let logFiles = try self.fileManager.contentsOfDirectory(
                    at: logsDirectory,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: .skipsHiddenFiles
                )
                
                for fileURL in logFiles {
                    guard fileURL.pathExtension == "log" else { continue }
                    
                    let attributes = try fileURL.resourceValues(forKeys: [.creationDateKey])
                    if let creationDate = attributes.creationDate, creationDate < cutoffDate {
                        try self.fileManager.removeItem(at: fileURL)
                    }
                }
            } catch {
                // Log cleanup failure is not critical
            }
        }
    }
    
    // MARK: - Utility
    
    /// Get the current log file URL
    var currentLogFileURL: URL? {
        return logFileURL
    }
    
    /// Get all log files
    func getAllLogFiles() -> [URL] {
        guard let logsDirectory = getLogsDirectory() else { return [] }
        
        do {
            return try fileManager.contentsOfDirectory(
                at: logsDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            ).filter { $0.pathExtension == "log" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
        } catch {
            return []
        }
    }
}
