//
//  MetalAudioProcessor.swift
//  EchoCorePro
//
//  Swift interface for Metal audio processing shaders
//

import Foundation
import Metal
import MetalPerformanceShaders

/// Metal-accelerated audio processor for real-time effects
final class MetalAudioProcessor: @unchecked Sendable {

    // MARK: - Metal Objects

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary

    // Compute pipelines
    private let deEsserPipeline: MTLComputePipelineState
    private let parametricEQPipeline: MTLComputePipelineState
    private let noiseGatePipeline: MTLComputePipelineState
    private let compressorPipeline: MTLComputePipelineState
    private let highPassPipeline: MTLComputePipelineState
    private let lowPassPipeline: MTLComputePipelineState
    private let waveformPipeline: MTLComputePipelineState

    private let logger = OSLogManager.shared

    // MARK: - Processing Parameters

    /// De-esser settings
    struct DeEsserSettings {
        var enabled: Bool = true
        var threshold: Float = 0.3
        var ratio: Float = 4.0
        var frequency: Float = 7000.0  // Hz
        var bandwidth: Float = 1.5  // Octaves
    }

    /// EQ Band settings
    struct EQBandSettings {
        var frequency: Float  // Hz
        var gain: Float  // dB (-12 to +12)
        var q: Float  // Q factor
    }

    /// Noise gate settings
    struct NoiseGateSettings {
        var enabled: Bool = true
        var threshold: Float = -40.0  // dB
        var attackMs: Float = 1.0
        var releaseMs: Float = 50.0
    }

    /// Compressor settings
    struct CompressorSettings {
        var enabled: Bool = true
        var threshold: Float = -20.0  // dB
        var ratio: Float = 4.0
        var attackMs: Float = 5.0
        var releaseMs: Float = 100.0
        var makeupGain: Float = 6.0  // dB
    }

    // MARK: - Initialization

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw AudioProcessorError.noMetalDevice
        }
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            throw AudioProcessorError.failedToCreateCommandQueue
        }
        self.commandQueue = commandQueue

        // Load Metal library from bundle
        guard let library = device.makeDefaultLibrary() else {
            throw AudioProcessorError.failedToLoadLibrary
        }
        self.library = library

        // Create compute pipelines
        deEsserPipeline = try Self.createPipeline(
            device: device, library: library, function: "deEsser")
        parametricEQPipeline = try Self.createPipeline(
            device: device, library: library, function: "parametricEQ")
        noiseGatePipeline = try Self.createPipeline(
            device: device, library: library, function: "noiseGate")
        compressorPipeline = try Self.createPipeline(
            device: device, library: library, function: "compressor")
        highPassPipeline = try Self.createPipeline(
            device: device, library: library, function: "highPassFilter")
        lowPassPipeline = try Self.createPipeline(
            device: device, library: library, function: "lowPassFilter")
        waveformPipeline = try Self.createPipeline(
            device: device, library: library, function: "generateWaveform")

        logger.log(
            "MetalAudioProcessor initialized on \(device.name)", category: .metal, level: .info)
    }

    private static func createPipeline(device: MTLDevice, library: MTLLibrary, function: String)
        throws -> MTLComputePipelineState
    {
        guard let function = library.makeFunction(name: function) else {
            throw AudioProcessorError.functionNotFound(function)
        }
        return try device.makeComputePipelineState(function: function)
    }

    // MARK: - Processing Methods

    /// Apply de-essing to audio buffer
    func applyDeEsser(
        samples: inout [Float],
        settings: DeEsserSettings,
        sampleRate: UInt32 = 16000
    ) throws {
        guard settings.enabled else { return }

        try processAudio(samples: &samples, pipeline: deEsserPipeline) { encoder, buffer in
            var threshold = settings.threshold
            var ratio = settings.ratio
            var frequency = settings.frequency
            var bandwidth = settings.bandwidth
            var rate = sampleRate

            encoder.setBuffer(buffer, offset: 0, index: 0)
            encoder.setBytes(&threshold, length: MemoryLayout<Float>.size, index: 1)
            encoder.setBytes(&ratio, length: MemoryLayout<Float>.size, index: 2)
            encoder.setBytes(&frequency, length: MemoryLayout<Float>.size, index: 3)
            encoder.setBytes(&bandwidth, length: MemoryLayout<Float>.size, index: 4)
            encoder.setBytes(&rate, length: MemoryLayout<UInt32>.size, index: 5)
        }
    }

    /// Apply noise gate to audio buffer
    func applyNoiseGate(
        samples: inout [Float],
        settings: NoiseGateSettings,
        sampleRate: UInt32 = 16000
    ) throws {
        guard settings.enabled else { return }

        // Create envelope buffer
        let envelopeBuffer = device.makeBuffer(
            length: samples.count * MemoryLayout<Float>.size, options: .storageModeShared)!

        try processAudio(samples: &samples, pipeline: noiseGatePipeline) { encoder, buffer in
            var threshold = settings.threshold
            var attack = settings.attackMs
            var release = settings.releaseMs
            var rate = sampleRate

            encoder.setBuffer(buffer, offset: 0, index: 0)
            encoder.setBytes(&threshold, length: MemoryLayout<Float>.size, index: 1)
            encoder.setBytes(&attack, length: MemoryLayout<Float>.size, index: 2)
            encoder.setBytes(&release, length: MemoryLayout<Float>.size, index: 3)
            encoder.setBytes(&rate, length: MemoryLayout<UInt32>.size, index: 4)
            encoder.setBuffer(envelopeBuffer, offset: 0, index: 5)
        }
    }

    /// Apply compressor to audio buffer
    func applyCompressor(
        samples: inout [Float],
        settings: CompressorSettings,
        sampleRate: UInt32 = 16000
    ) throws {
        guard settings.enabled else { return }

        let envelopeBuffer = device.makeBuffer(
            length: samples.count * MemoryLayout<Float>.size, options: .storageModeShared)!

        try processAudio(samples: &samples, pipeline: compressorPipeline) { encoder, buffer in
            var threshold = settings.threshold
            var ratio = settings.ratio
            var attack = settings.attackMs
            var release = settings.releaseMs
            var makeup = settings.makeupGain
            var rate = sampleRate

            encoder.setBuffer(buffer, offset: 0, index: 0)
            encoder.setBytes(&threshold, length: MemoryLayout<Float>.size, index: 1)
            encoder.setBytes(&ratio, length: MemoryLayout<Float>.size, index: 2)
            encoder.setBytes(&attack, length: MemoryLayout<Float>.size, index: 3)
            encoder.setBytes(&release, length: MemoryLayout<Float>.size, index: 4)
            encoder.setBytes(&makeup, length: MemoryLayout<Float>.size, index: 5)
            encoder.setBytes(&rate, length: MemoryLayout<UInt32>.size, index: 6)
            encoder.setBuffer(envelopeBuffer, offset: 0, index: 7)
        }
    }

    /// Apply high-pass filter
    func applyHighPass(
        samples: inout [Float],
        cutoff: Float,
        sampleRate: UInt32 = 16000
    ) throws {
        let prevInputBuffer = device.makeBuffer(
            length: samples.count * MemoryLayout<Float>.size, options: .storageModeShared)!
        let prevOutputBuffer = device.makeBuffer(
            length: samples.count * MemoryLayout<Float>.size, options: .storageModeShared)!

        try processAudio(samples: &samples, pipeline: highPassPipeline) { encoder, buffer in
            var cutoffVal = cutoff
            var rate = sampleRate

            encoder.setBuffer(buffer, offset: 0, index: 0)
            encoder.setBytes(&cutoffVal, length: MemoryLayout<Float>.size, index: 1)
            encoder.setBytes(&rate, length: MemoryLayout<UInt32>.size, index: 2)
            encoder.setBuffer(prevInputBuffer, offset: 0, index: 3)
            encoder.setBuffer(prevOutputBuffer, offset: 0, index: 4)
        }
    }

    /// Apply low-pass filter
    func applyLowPass(
        samples: inout [Float],
        cutoff: Float,
        sampleRate: UInt32 = 16000
    ) throws {
        let prevOutputBuffer = device.makeBuffer(
            length: samples.count * MemoryLayout<Float>.size, options: .storageModeShared)!

        try processAudio(samples: &samples, pipeline: lowPassPipeline) { encoder, buffer in
            var cutoffVal = cutoff
            var rate = sampleRate

            encoder.setBuffer(buffer, offset: 0, index: 0)
            encoder.setBytes(&cutoffVal, length: MemoryLayout<Float>.size, index: 1)
            encoder.setBytes(&rate, length: MemoryLayout<UInt32>.size, index: 2)
            encoder.setBuffer(prevOutputBuffer, offset: 0, index: 3)
        }
    }

    /// Generate waveform data for visualization
    func generateWaveform(
        from samples: [Float],
        width: Int
    ) throws -> [(min: Float, max: Float)] {
        let samplesPerPixel = max(1, samples.count / width)
        var waveformData = [(min: Float, max: Float)](repeating: (0, 0), count: width)

        // Create buffers
        guard
            let inputBuffer = device.makeBuffer(
                bytes: samples, length: samples.count * MemoryLayout<Float>.size,
                options: .storageModeShared),
            let outputBuffer = device.makeBuffer(
                length: width * MemoryLayout<SIMD2<Float>>.size, options: .storageModeShared)
        else {
            throw AudioProcessorError.failedToCreateBuffer
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            throw AudioProcessorError.failedToCreateCommandBuffer
        }

        encoder.setComputePipelineState(waveformPipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)

        var spp = UInt32(samplesPerPixel)
        var length = UInt32(samples.count)
        encoder.setBytes(&spp, length: MemoryLayout<UInt32>.size, index: 2)
        encoder.setBytes(&length, length: MemoryLayout<UInt32>.size, index: 3)

        let threadsPerGrid = MTLSize(width: width, height: 1, depth: 1)
        let threadsPerGroup = MTLSize(
            width: min(width, waveformPipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read back results
        let resultPtr = outputBuffer.contents().bindMemory(to: SIMD2<Float>.self, capacity: width)
        for i in 0..<width {
            waveformData[i] = (min: resultPtr[i].x, max: resultPtr[i].y)
        }

        return waveformData
    }

    /// Apply full processing chain
    func processFullChain(
        samples: inout [Float],
        deEsser: DeEsserSettings = DeEsserSettings(),
        noiseGate: NoiseGateSettings = NoiseGateSettings(),
        compressor: CompressorSettings = CompressorSettings(),
        highPassCutoff: Float? = 80,  // Remove rumble below 80Hz
        sampleRate: UInt32 = 16000
    ) throws {
        // Apply effects in order
        if let hpCutoff = highPassCutoff {
            try applyHighPass(samples: &samples, cutoff: hpCutoff, sampleRate: sampleRate)
        }

        try applyNoiseGate(samples: &samples, settings: noiseGate, sampleRate: sampleRate)
        try applyDeEsser(samples: &samples, settings: deEsser, sampleRate: sampleRate)
        try applyCompressor(samples: &samples, settings: compressor, sampleRate: sampleRate)
    }

    // MARK: - Private Helpers

    private func processAudio(
        samples: inout [Float],
        pipeline: MTLComputePipelineState,
        configure: (MTLComputeCommandEncoder, MTLBuffer) -> Void
    ) throws {
        guard
            let buffer = device.makeBuffer(
                bytes: samples, length: samples.count * MemoryLayout<Float>.size,
                options: .storageModeShared)
        else {
            throw AudioProcessorError.failedToCreateBuffer
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            throw AudioProcessorError.failedToCreateCommandBuffer
        }

        encoder.setComputePipelineState(pipeline)
        configure(encoder, buffer)

        let threadsPerGrid = MTLSize(width: samples.count, height: 1, depth: 1)
        let threadsPerGroup = MTLSize(
            width: min(samples.count, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1)
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read back processed samples
        let resultPtr = buffer.contents().bindMemory(to: Float.self, capacity: samples.count)
        for i in 0..<samples.count {
            samples[i] = resultPtr[i]
        }
    }

    // MARK: - Errors

    enum AudioProcessorError: Error, LocalizedError {
        case noMetalDevice
        case failedToCreateCommandQueue
        case failedToLoadLibrary
        case functionNotFound(String)
        case failedToCreateBuffer
        case failedToCreateCommandBuffer

        var errorDescription: String? {
            switch self {
            case .noMetalDevice:
                return "No Metal-compatible GPU found"
            case .failedToCreateCommandQueue:
                return "Failed to create Metal command queue"
            case .failedToLoadLibrary:
                return "Failed to load Metal shader library"
            case .functionNotFound(let name):
                return "Metal function '\(name)' not found"
            case .failedToCreateBuffer:
                return "Failed to create Metal buffer"
            case .failedToCreateCommandBuffer:
                return "Failed to create command buffer"
            }
        }
    }
}
