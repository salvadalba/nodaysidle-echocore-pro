# Technical Requirements Document

## 🧭 System Context
EchoCore Pro is a native macOS voice server application running entirely on-device. Built with SwiftUI for the frontend and Swift/Combine for backend services, it leverages Metal for audio acceleration, CoreML/NaturalLanguage for model inference, and SwiftData for local persistence. The app bundles a Python runtime for model quantization and runs a local HTTP server on localhost for inter-process communication between UI components and background inference services.

## 🔌 API Contracts
### ModelDownloadAPI
- **Method:** POST
- **Path:** /api/models/download
- **Auth:** None (localhost only)
- **Request:** {"model_id": "string", "version": "string", "destination_path": "string"}
- **Response:** {"download_id": "uuid", "status": "downloading|queued", "progress": 0.0}
- **Errors:**
- 409: Model already exists
- 503: Download queue full
- 422: Invalid model ID

### ModelDownloadProgress
- **Method:** GET
- **Path:** /api/models/download/{download_id}/progress
- **Auth:** None (localhost only)
- **Request:** 
- **Response:** {"download_id": "uuid", "progress": 0.85, "bytes_downloaded": 425000000, "total_bytes": 500000000, "status": "downloading|completed|failed|paused", "eta_seconds": 45}
- **Errors:**
- 404: Download not found

### ModelQuantization
- **Method:** POST
- **Path:** /api/models/quantize
- **Auth:** None (localhost only)
- **Request:** {"model_path": "string", "quantization_type": "int4|int8", "output_path": "string"}
- **Response:** {"job_id": "uuid", "status": "queued|processing", "estimated_duration_seconds": 300}
- **Errors:**
- 404: Model file not found
- 422: Invalid quantization type
- 503: No available GPU resources

### InferenceRequest
- **Method:** POST
- **Path:** /api/inference/stt
- **Auth:** None (localhost only)
- **Request:** {"audio_data": "base64_encoded_pcm", "model_id": "string", "language": "string", "sample_rate": 16000}
- **Response:** {"text": "transcribed text", "confidence": 0.98, "processing_time_ms": 245, "tokens": []}
- **Errors:**
- 400: Invalid audio format
- 404: Model not loaded
- 503: Inference queue full

### InferenceRequestTTS
- **Method:** POST
- **Path:** /api/inference/tts
- **Auth:** None (localhost only)
- **Request:** {"text": "string", "model_id": "string", "voice": "string", "speed": 1.0}
- **Response:** {"audio_data": "base64_encoded_pcm", "sample_rate": 24000, "duration_ms": 1250, "processing_time_ms": 180}
- **Errors:**
- 400: Text too long
- 404: Model not loaded
- 503: Inference queue full

### AudioProcess
- **Method:** POST
- **Path:** /api/audio/process
- **Auth:** None (localhost only)
- **Request:** {"audio_data": "base64_encoded_pcm", "operations": [{"type": "de_ess|eq", "parameters": {}}], "sample_rate": 48000}
- **Response:** {"processed_audio": "base64_encoded_pcm", "processing_time_ms": 12}
- **Errors:**
- 400: Invalid operation
- 422: Invalid parameters

### ModelList
- **Method:** GET
- **Path:** /api/models
- **Auth:** None (localhost only)
- **Request:** 
- **Response:** {"models": [{"id": "string", "name": "string", "type": "stt|tts|multilingual", "status": "loaded|unloaded", "size_bytes": 500000000, "quantized": true}]}
- **Errors:**
_None_

### ModelLoadUnload
- **Method:** PUT
- **Path:** /api/models/{model_id}/status
- **Auth:** None (localhost only)
- **Request:** {"action": "load|unload"}
- **Response:** {"model_id": "string", "status": "loaded|unloaded", "memory_mb": 850}
- **Errors:**
- 404: Model not found
- 503: Insufficient memory

### HotkeyRegister
- **Method:** POST
- **Path:** /api/hotkeys/register
- **Auth:** None (localhost only)
- **Request:** {"key_combination": "string", "action": "toggle_recording|start_dictation|cancel", "app_filter": "string|null"}
- **Response:** {"hotkey_id": "uuid", "registered": true}
- **Errors:**
- 409: Hotkey already in use
- 422: Invalid key combination

### Settings
- **Method:** GET
- **Path:** /api/settings
- **Auth:** None (localhost only)
- **Request:** 
- **Response:** {"default_model": "string", "auto_quantize": true, "memory_limit_mb": 2048, "hotkeys_enabled": true}
- **Errors:**
_None_

### SettingsUpdate
- **Method:** PUT
- **Path:** /api/settings
- **Auth:** None (localhost only)
- **Request:** {"default_model": "string", "auto_quantize": true, "memory_limit_mb": 2048, "hotkeys_enabled": true}
- **Response:** {"updated": true}
- **Errors:**
- 422: Invalid setting value

## 🧱 Modules
### AppModule
- **Responsibilities:**
- Application lifecycle management
- Dependency injection container
- Error handling coordinator
- **Interfaces:**
- AppProtocol: main(), shutdown(), handleError(error:)
- **Depends on:**
- ViewModelRegistry
- ServiceRegistry

### ModelManagementModule
- **Responsibilities:**
- Model metadata storage
- Download orchestration
- Quantization job management
- Model version tracking
- **Interfaces:**
- ModelRepository: fetch(), save(), delete()
- DownloadQueue: enqueue(model:), pause(id:), resume(id:)
- QuantizationManager: start(model:, type:), getStatus(jobId:)
- **Depends on:**
- SwiftData
- NetworkModule
- LocalHTTPServer

### InferenceEngineModule
- **Responsibilities:**
- CoreML model loading
- Request queuing
- Token generation
- Resource management
- **Interfaces:**
- InferenceEngine: load(model:), unload(model:), process(audio:), process(text:)
- InferenceQueue: enqueue(request:), dequeue()
- ResourceManager: allocateMemory(size:), releaseMemory(id:)
- **Depends on:**
- CoreML
- NaturalLanguage
- AudioProcessingModule

### AudioProcessingModule
- **Responsibilities:**
- Metal shader execution
- De-essing processing
- EQ application
- Waveform rendering
- **Interfaces:**
- AudioPipeline: process(audio:, operations:)
- MetalProcessor: applyDeEss(audio:), applyEQ(audio:, curve:)
- WaveformRenderer: generateTexture(from:, width:, height:)
- **Depends on:**
- Metal
- Accelerate

### NetworkModule
- **Responsibilities:**
- HTTP download management
- Resume capability
- Progress tracking
- Network reachability
- **Interfaces:**
- DownloadManager: startDownload(url:, destination:), pause(id:), resume(id:), cancel(id:)
- ProgressTracker: report(progress:, for:)
- **Depends on:**
- URLSession

### LocalHTTPServerModule
- **Responsibilities:**
- Local server lifecycle
- Request routing
- Response serialization
- WebSocket support for streaming
- **Interfaces:**
- HTTPServer: start(port:), stop()
- Router: register(route:, handler:)
- RequestHandler: handle(request:) -> Response
- **Depends on:**
- Network.framework

### HotkeyModule
- **Responsibilities:**
- Global hotkey registration
- Keyboard event monitoring
- App-specific filtering
- Action dispatching
- **Interfaces:**
- HotkeyManager: register(key:, action:), unregister(id:), enable(), disable()
- EventMonitor: startMonitoring(), stopMonitoring()
- **Depends on:**
- AppKit
- Carbon

### UIModule
- **Responsibilities:**
- View rendering
- User input handling
- State presentation
- Animations
- **Interfaces:**
- ModelListView: View
- DownloadProgressView: View
- SettingsView: View
- WaveformVisualizer: View
- **Depends on:**
- SwiftUI
- ViewModelModule

### ViewModelModule
- **Responsibilities:**
- View state management
- Business logic coordination
- Data transformation
- Error presentation
- **Interfaces:**
- ModelListViewModel: ObservableObject
- DownloadViewModel: ObservableObject
- InferenceViewModel: ObservableObject
- SettingsViewModel: ObservableObject
- **Depends on:**
- Combine
- ModelManagementModule
- InferenceEngineModule

### PersistenceModule
- **Responsibilities:**
- SwiftData schema management
- Entity CRUD
- Migration handling
- Query execution
- **Interfaces:**
- DataStore: save(_:), fetch(_:), delete(_:)
- **Depends on:**
- SwiftData

### PythonRuntimeModule
- **Responsibilities:**
- Bundled Python runtime management
- Quantization script execution
- Environment isolation
- stdout/stderr capture
- **Interfaces:**
- PythonExecutor: execute(script:, args:), execute(file:, args:)
- EnvironmentManager: setup(), cleanup()
- **Depends on:**
- Process
- Foundation

## 🗃 Data Model Notes
- SwiftData @Model: LocalModelEntity { id: UUID, name: String, type: ModelType, version: String, filePath: String, sizeBytes: Int64, isQuantized: Bool, quantizationType: QuantizationType?, dateDownloaded: Date, lastUsed: Date }
- SwiftData @Model: DownloadJobEntity { id: UUID, modelId: UUID, url: URL, destinationPath: String, progress: Double, bytesDownloaded: Int64, totalBytes: Int64, status: DownloadStatus, startDate: Date, pausedDate: Date?, completedDate: Date?, error: String? }
- SwiftData @Model: QuantizationJobEntity { id: UUID, sourceModelId: UUID, sourcePath: String, outputPath: String, quantizationType: QuantizationType, status: JobStatus, progress: Double, startDate: Date, completedDate: Date?, error: String? }
- SwiftData @Model: ProcessingHistoryEntity { id: UUID, modelId: UUID, processingType: ProcessingType, inputLength: Double, outputLength: Double, processingTimeMs: Int, timestamp: Date }
- SwiftData @Model: UserSettingsEntity { id: UUID (persistent), defaultModelId: UUID?, autoQuantize: Bool, memoryLimitMB: Int, hotkeysEnabled: Bool, downloadLocation: URL, preferredLanguage: Language }
- SwiftData @Model: HotkeyEntity { id: UUID, keyCombination: String, modifiers: Set<KeyModifier>, action: HotkeyAction, appFilter: String?, isEnabled: Bool }
- ModelType enum: stt, tts, multilingual, embedding
- DownloadStatus enum: queued, downloading, paused, completed, failed, cancelled
- JobStatus enum: queued, processing, completed, failed, cancelled
- QuantizationType enum: int4, int8, fp16
- ProcessingType enum: speechToText, textToSpeech, audioPostProcessing
- HotkeyAction enum: toggleRecording, startDictation, cancel, pauseResume

## 🔐 Validation & Security
- Local HTTP server binds exclusively to 127.0.0.1, never exposed to network interfaces
- Download sources restricted to hardcoded whitelist of model repositories (HuggingFace, GitHub)
- Model files validated with SHA-256 checksum verification before loading into CoreML
- Quantization scripts execute in isolated subprocess with restricted filesystem access
- Hotkey registration requires explicit user permission via system prompt
- Audio input sanitized: sample rate validation, format conversion, amplitude clipping protection
- SwiftData queries use parameterized predicates to prevent injection
- App bundle code-signed with hardened runtime; entitlements for microphone, network (downloads only)

## 🧯 Error Handling Strategy
Combine-based error propagation from services through view models to views. Local HTTP server returns standardized JSON error responses {error: string, code: int, details: string?}. Critical errors logged to local file with crash diagnostics. User-facing errors use SwiftUI .alert() modifiers. Background operations retry with exponential backoff (max 3 attempts). Download failures auto-pause with user notification. Model load failures gracefully degrade to next available model or unload with memory cleanup.

## 🔭 Observability
- **Logging:** OSLog subsystem: com.echocore.pro. Categories: networking, inference, metal, storage, lifecycle. Log levels: debug for development, info/release for production. Persist logs to ~/Library/Logs/EchoCorePro/ with 30-day retention.
- **Tracing:** Instrument instruments for Time Profiler and Metal Performance Graphs. Signpost intervals for model loading, quantization jobs, download operations. Span propagation from UI action through HTTP request to inference response.
- **Metrics:**
- Inference latency (p50, p95, p99)
- Memory usage per loaded model
- Download throughput
- Metal frame times
- Active inference queue depth
- Hotkey trigger frequency
- Error rates by category

## ⚡ Performance Notes
- Inference requests target <500ms end-to-end latency; model preloading on app launch for default model
- Metal shaders compiled at app first launch and cached to avoid runtime compilation delay
- Model downloads use URLSession with maximum 4 concurrent connections, resumable using Range headers
- SwiftData queries optimized with @Query sorting and pagination for model lists >100 items
- Waveform rendering uses Metal compute for 60fps even with 60+ minute audio files
- Memory management: inactive models auto-unload when memory exceeds user-defined threshold
- Background tasks use Swift Task/Actor for non-blocking model operations

## 🧪 Testing Strategy
### Unit
- ViewModel state transitions with Combine publisher expectations
- Download progress calculation edge cases
- Quantization parameter validation
- Metal shader unit tests with mock textures
- SwiftData CRUD operations with in-memory container
### Integration
- Local HTTP server request/response cycles
- Model download from mock server endpoint
- Quantization script execution with test Python environment
- CoreML model loading/unloading with memory verification
- Hotkey registration and trigger handling
### E2E
- Full download-quantize-inference pipeline
- Multi-model concurrent inference under memory pressure
- Large file download pause/resume/cancel scenarios
- UI navigation flows with XCTest UI framework
- Metal waveform rendering performance with multi-hour audio files

## 🚀 Rollout Plan
- Phase 1: Core infrastructure (HTTP server, SwiftData schema, basic UI scaffolding)
- Phase 2: Model download from HuggingFace with progress UI
- Phase 3: Python runtime integration and quantization for int8/int4 models
- Phase 4: CoreML inference integration (STT only)
- Phase 5: Metal audio post-processing (de-ess, EQ)
- Phase 6: TTS inference and multilingual model support
- Phase 7: Hotkey system and global dictation mode
- Phase 8: Polish: animations, waveform visualizer, settings persistence

## ❓ Open Questions
_None_