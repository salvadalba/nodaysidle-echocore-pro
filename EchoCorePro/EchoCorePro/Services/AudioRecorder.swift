//
//  AudioRecorder.swift
//  EchoCorePro
//
//  Manages microphone recording with real-time audio levels
//

import Foundation
import AVFoundation
import Combine
import AppKit

/// Observable audio recorder for microphone input
@MainActor
final class AudioRecorder: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isRecording = false
    @Published private(set) var recordingTime: TimeInterval = 0
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var recordedFileURL: URL?
    @Published private(set) var error: Error?
    
    // For waveform visualization
    @Published private(set) var audioLevels: [Float] = Array(repeating: 0, count: 50)
    
    // MARK: - Private Properties
    
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingTimer: Timer?
    private var audioSamples: [Float] = []
    private let logger = OSLogManager.shared
    
    // Recording settings
    private let sampleRate: Double = 16000
    private let channelCount: AVAudioChannelCount = 1
    
    // MARK: - Initialization
    
    init() {
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Start recording from the microphone
    func startRecording() async throws {
        guard !isRecording else { return }
        
        logger.log("Starting audio recording", category: .inference, level: .info)
        
        // Request microphone permission
        let granted = await requestMicrophonePermission()
        guard granted else {
            throw RecordingError.permissionDenied
        }
        
        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw RecordingError.engineInitFailed
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Create recording format (16kHz mono for Whisper)
        guard let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else {
            throw RecordingError.invalidFormat
        }
        
        // Create temp file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "echocore_recording_\(Date().timeIntervalSince1970).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            audioFile = try AVAudioFile(
                forWriting: fileURL,
                settings: recordingFormat.settings
            )
            recordedFileURL = fileURL
        } catch {
            throw RecordingError.fileCreationFailed(error.localizedDescription)
        }
        
        // Install tap on input
        let converter = AVAudioConverter(from: inputFormat, to: recordingFormat)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // Convert to recording format
            if let converter = converter {
                let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: recordingFormat,
                    frameCapacity: AVAudioFrameCount(recordingFormat.sampleRate * Double(buffer.frameLength) / inputFormat.sampleRate)
                )!
                
                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
                
                if error == nil {
                    Task { @MainActor in
                        self.processAudioBuffer(convertedBuffer)
                    }
                }
            }
        }
        
        // Start engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start timer
        recordingTime = 0
        audioSamples = []
        isRecording = true
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingTime += 0.1
            }
        }
        
        logger.log("Recording started", category: .inference, level: .info)
    }
    
    /// Stop recording and return the audio file URL
    /// - Returns: URL to the recorded audio file
    @discardableResult
    func stopRecording() async -> URL? {
        guard isRecording else { return nil }
        
        logger.log("Stopping audio recording", category: .inference, level: .info)
        
        // Stop timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Stop engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        
        // Close audio file
        audioFile = nil
        
        isRecording = false
        
        logger.log("Recording stopped. Duration: \(String(format: "%.1f", recordingTime))s", category: .inference, level: .info)
        
        return recordedFileURL
    }
    
    /// Get the recorded audio samples
    func getAudioSamples() -> [Float] {
        return audioSamples
    }
    
    /// Cancel recording and delete the file
    func cancelRecording() async {
        await stopRecording()
        
        // Delete the recorded file
        if let url = recordedFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        recordedFileURL = nil
        recordingTime = 0
        audioSamples = []
        audioLevels = Array(repeating: 0, count: 50)
    }
    
    // MARK: - Private Methods
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        
        // Add to samples array
        audioSamples.append(contentsOf: samples)
        
        // Write to file
        do {
            try audioFile?.write(from: buffer)
        } catch {
            logger.log("Failed to write audio: \(error)", category: .inference, level: .error)
        }
        
        // Calculate audio level (RMS)
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(frameLength))
        let level = min(1.0, rms * 10) // Normalize
        
        audioLevel = level
        
        // Update waveform visualization
        audioLevels.removeFirst()
        audioLevels.append(level)
    }
    
    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.cancelRecording()
            }
        }
    }
    
    // MARK: - Error Types
    
    enum RecordingError: Error, LocalizedError {
        case permissionDenied
        case engineInitFailed
        case invalidFormat
        case fileCreationFailed(String)
        case recordingFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Microphone permission was denied. Please enable it in System Preferences."
            case .engineInitFailed:
                return "Failed to initialize audio engine"
            case .invalidFormat:
                return "Invalid audio format"
            case .fileCreationFailed(let reason):
                return "Failed to create recording file: \(reason)"
            case .recordingFailed(let reason):
                return "Recording failed: \(reason)"
            }
        }
    }
}
