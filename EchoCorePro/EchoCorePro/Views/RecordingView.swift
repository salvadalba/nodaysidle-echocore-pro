//
//  RecordingView.swift
//  EchoCorePro
//
//  Voice recording interface with waveform visualization and audio processing
//

import AVFoundation
import SwiftUI

struct RecordingView: View {
    @StateObject private var recorder = AudioRecorder()
    @State private var transcribedText = ""
    @State private var isProcessing = false
    @State private var isLoadingModel = false
    @State private var showResult = false
    @State private var errorMessage: String?
    @State private var selectedModel = "base"
    @State private var showAudioControls = false
    @State private var showWhisperTuning = false

    // Audio processing settings
    @State private var deEsserEnabled = true
    @State private var deEsserThreshold: Float = 0.3
    @State private var noiseGateEnabled = true
    @State private var noiseGateThreshold: Float = -40
    @State private var compressorEnabled = true
    @State private var compressorRatio: Float = 4.0
    @State private var highPassEnabled = true
    @State private var highPassCutoff: Float = 80

    // Whisper advanced tuning parameters
    @State private var whisperTemperature: Float = 0.0
    @State private var beamSize: Int = 5
    @State private var bestOf: Int = 5
    @State private var compressionRatioThreshold: Float = 2.4
    @State private var logprobThreshold: Float = -1.0
    @State private var noSpeechThreshold: Float = 0.6

    private let availableModels = ["tiny", "base", "small", "medium", "large-v3"]
    private let inferenceService = InferenceService()

    var body: some View {
        HStack(spacing: 0) {
            // Main recording area
            VStack(spacing: 0) {
                headerBar

                VStack(spacing: 32) {
                    Spacer()
                    statusIndicator
                    waveformView
                        .frame(height: 120)
                        .padding(.horizontal, 32)

                    Text(formatTime(recorder.recordingTime))
                        .font(.system(size: 56, weight: .ultraLight, design: .monospaced))
                        .foregroundStyle(recorder.isRecording ? .primary : .secondary)

                    recordButton

                    Spacer()

                    if showResult || !transcribedText.isEmpty {
                        resultArea
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding()

                if let error = errorMessage {
                    errorBanner(error)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Audio processing sidebar
            if showAudioControls {
                audioControlsSidebar
                    .frame(width: 280)
                    .transition(.move(edge: .trailing))
            }
            
            // Whisper tuning sidebar
            if showWhisperTuning {
                whisperTuningSidebar
                    .frame(width: 280)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(
            LinearGradient(
                colors: [Color(white: 0.05), Color(white: 0.08), Color(white: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Text("Voice Recording")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            // Model selector
            Picker("Model", selection: $selectedModel) {
                ForEach(availableModels, id: \.self) { model in
                    Text(model.capitalized).tag(model)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)

            // Audio controls toggle
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showAudioControls.toggle()
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(showAudioControls ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .help("Audio Processing Controls")
            
            // Whisper tuning toggle
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showWhisperTuning.toggle()
                }
            } label: {
                Image(systemName: "waveform.and.mic")
                    .font(.title3)
                    .foregroundStyle(showWhisperTuning ? .purple : .secondary)
            }
            .buttonStyle(.plain)
            .help("Whisper Tuning Parameters")
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Audio Controls Sidebar

    private var audioControlsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Audio Processing")
                    .font(.headline)
                    .padding(.bottom, 4)

                // De-esser
                audioControlSection(
                    title: "De-esser",
                    icon: "waveform.badge.minus",
                    enabled: $deEsserEnabled,
                    color: .blue
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        sliderRow(
                            label: "Threshold", value: $deEsserThreshold, range: 0.1...1.0,
                            format: "%.1f")
                    }
                }

                // Noise Gate
                audioControlSection(
                    title: "Noise Gate",
                    icon: "speaker.slash",
                    enabled: $noiseGateEnabled,
                    color: .green
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        sliderRow(
                            label: "Threshold", value: $noiseGateThreshold, range: -60...0,
                            suffix: " dB")
                    }
                }

                // Compressor
                audioControlSection(
                    title: "Compressor",
                    icon: "waveform.path",
                    enabled: $compressorEnabled,
                    color: .orange
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        sliderRow(
                            label: "Ratio", value: $compressorRatio, range: 1...20, format: "%.0f:1"
                        )
                    }
                }

                // High-Pass Filter
                audioControlSection(
                    title: "High-Pass Filter",
                    icon: "waveform.badge.exclamationmark",
                    enabled: $highPassEnabled,
                    color: .purple
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        sliderRow(
                            label: "Cutoff", value: $highPassCutoff, range: 20...200, suffix: " Hz")
                    }
                }

                Divider()
                    .padding(.vertical, 8)

                // Processing chain info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Processing Chain")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Text("HP Filter → Noise Gate → De-esser → Compressor")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
        }
        .background(Color(white: 0.1))
    }

    // MARK: - Whisper Tuning Sidebar

    private var whisperTuningSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Whisper Tuning")
                    .font(.headline)
                    .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Decoding Parameters")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)

                    // Temperature
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Temperature")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2f", whisperTemperature))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        Slider(value: $whisperTemperature, in: 0.0...1.0, step: 0.05)
                            .tint(.purple)
                        Text("Controls randomness in decoding. 0 = greedy, higher = more creative")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.15))
                    )

                    // Beam Size
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Beam Size")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(beamSize)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        Stepper("", value: $beamSize, in: 1...10)
                        Text("Number of beams for beam search. Higher = more accurate but slower")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.15))
                    )

                    // Best Of
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Best Of")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(bestOf)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        Stepper("", value: $bestOf, in: 1...10)
                        Text("Number of candidates to generate when sampling. Higher = better quality")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.15))
                    )

                    Divider().padding(.vertical, 8)

                    Text("Quality Thresholds")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)

                    // Compression Ratio Threshold
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Compression Ratio")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f", compressionRatioThreshold))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        Slider(value: $compressionRatioThreshold, in: 1.0...5.0, step: 0.1)
                            .tint(.purple)
                        Text("Detect text repetition. Lower = stricter filtering")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.15))
                    )

                    // Log Probability Threshold
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Log Prob Threshold")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f", logprobThreshold))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        Slider(value: $logprobThreshold, in: -2.0...0.0, step: 0.1)
                            .tint(.purple)
                        Text("Minimum log probability for segments. Lower = stricter")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.15))
                    )

                    // No Speech Threshold
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("No Speech Threshold")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2f", noSpeechThreshold))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        Slider(value: $noSpeechThreshold, in: 0.0...1.0, step: 0.05)
                            .tint(.purple)
                        Text("Probability threshold to skip silent segments")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.15))
                    )

                    Divider().padding(.vertical, 8)

                    // Reset to defaults
                    Button {
                        resetWhisperDefaults()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .background(Color(white: 0.1))
    }

    private func resetWhisperDefaults() {
        whisperTemperature = 0.0
        beamSize = 5
        bestOf = 5
        compressionRatioThreshold = 2.4
        logprobThreshold = -1.0
        noSpeechThreshold = 0.6
    }

    private func audioControlSection<Content: View>(
        title: String,
        icon: String,
        enabled: Binding<Bool>,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(enabled.wrappedValue ? color : .gray)
                    .frame(width: 20)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Toggle("", isOn: enabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.7)
            }

            if enabled.wrappedValue {
                content()
                    .padding(.leading, 28)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.15))
        )
        .animation(.spring(response: 0.3), value: enabled.wrappedValue)
    }

    private func sliderRow(
        label: String, value: Binding<Float>, range: ClosedRange<Float>, format: String = "%.0f",
        suffix: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: format, value.wrappedValue) + suffix)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            Slider(value: value, in: range)
                .tint(.blue)
        }
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .shadow(color: recorder.isRecording ? .red.opacity(0.6) : .clear, radius: 6)

            Text(statusText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        if isLoadingModel { return .yellow }
        if recorder.isRecording { return .red }
        if isProcessing { return .orange }
        if !transcribedText.isEmpty { return .green }
        return .gray
    }

    private var statusText: String {
        if isLoadingModel { return "Loading \(selectedModel) model..." }
        if recorder.isRecording { return "Recording..." }
        if isProcessing { return "Transcribing with \(selectedModel)..." }
        if !transcribedText.isEmpty { return "Transcription complete" }
        return "Ready to record"
    }

    // MARK: - Waveform View

    private var waveformView: some View {
        HStack(spacing: 3) {
            ForEach(0..<recorder.audioLevels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: recorder.isRecording
                                ? [.blue, .purple, .pink]
                                : [.gray.opacity(0.3), .gray.opacity(0.5)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: max(4, CGFloat(recorder.audioLevels[index]) * 100))
                    .animation(
                        .spring(response: 0.1, dampingFraction: 0.5),
                        value: recorder.audioLevels[index])
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(recorder.isRecording ? 1 : 0.4)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button {
            Task { await toggleRecording() }
        } label: {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 110, height: 110)

                if recorder.isRecording {
                    Circle()
                        .stroke(.red.opacity(0.4), lineWidth: 25)
                        .frame(width: 110, height: 110)
                        .scaleEffect(1.4)
                        .opacity(0.6)
                }

                Circle()
                    .fill(
                        recorder.isRecording
                            ? AnyShapeStyle(Color.red)
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [.blue, .purple], startPoint: .topLeading,
                                    endPoint: .bottomTrailing))
                    )
                    .frame(width: 80, height: 80)
                    .shadow(
                        color: recorder.isRecording ? .red.opacity(0.5) : .purple.opacity(0.3),
                        radius: 10)

                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(isProcessing || isLoadingModel)
        .scaleEffect(isProcessing ? 0.9 : 1.0)
        .animation(.spring(response: 0.3), value: isProcessing)
    }

    // MARK: - Result Area

    private var resultArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "text.quote")
                        .foregroundStyle(.blue)
                    Text("Transcription")
                        .font(.headline)
                }

                Spacer()

                if !transcribedText.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(transcribedText, forType: .string)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)

                    Button {
                        transcribedText = ""
                        showResult = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isProcessing {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing audio with \(selectedModel) model...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                Text(transcribedText.isEmpty ? "No transcription yet" : transcribedText)
                    .font(.body)
                    .foregroundStyle(transcribedText.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10)
        )
        .padding(.horizontal)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.subheadline)
            Spacer()
            Button {
                withAnimation { errorMessage = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.red.opacity(0.2))
        .transition(.move(edge: .bottom))
    }

    // MARK: - Actions

    private func toggleRecording() async {
        if recorder.isRecording {
            // Stop recording and transcribe
            let audioURL = await recorder.stopRecording()

            guard let url = audioURL else {
                errorMessage = "No audio recorded"
                return
            }

            withAnimation {
                isProcessing = true
                showResult = true
            }

            do {
                // Load model if not already loaded
                let currentModelName = await inferenceService.loadedModelName
                if currentModelName != selectedModel {
                    withAnimation { isLoadingModel = true }
                    try await inferenceService.loadModel(named: selectedModel)
                    withAnimation { isLoadingModel = false }
                }

                // Transcribe
                let result = try await inferenceService.transcribe(audioPath: url)

                withAnimation {
                    transcribedText = result.text
                    isProcessing = false
                }
            } catch {
                withAnimation {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                    isLoadingModel = false
                }
            }
        } else {
            // Start recording
            withAnimation {
                transcribedText = ""
                showResult = false
                errorMessage = nil
            }

            do {
                try await recorder.startRecording()
            } catch {
                withAnimation {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

#Preview {
    RecordingView()
        .frame(width: 900, height: 600)
}
