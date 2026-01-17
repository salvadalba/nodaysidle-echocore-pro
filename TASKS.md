# Tasks Plan — EchoCore Pro

## 📌 Global Assumptions
- Development on macOS 15+ with Xcode 16+
- Target macOS 14+ minimum deployment
- Developer has macOS device with microphone for testing
- HuggingFace model repository accessible during development
- Python 3.11+ embedding build bundled with app

## ⚠️ Risks
- CoreML model format may require conversion from PyTorch/HuggingFace formats
- Metal shader debugging requires macOS-specific tools
- App Sandbox restrictions may impact subprocess execution
- Quantization script dependencies may increase app bundle size significantly
- Hotkey system requires Accessibility permission which users may deny

## 🧩 Epics
## Foundation & Scaffolding
**Goal:** Set up Xcode project, build infrastructure, and core application lifecycle

### ✅ Create Xcode project and app structure (2-3 hours)

Initialize macOS app project with SwiftUI, configure bundle identifier, code signing, and entitlements

**Acceptance Criteria**
- Xcode project builds without errors
- App launches and shows empty window
- Entitlements configured for microphone and network
- Info.plist includes required macOS keys

**Dependencies**
_None_
### ✅ Implement AppCoordinator and dependency injection container (2-3 hours)

Create AppProtocol main entry point, ServiceRegistry, and ViewModelRegistry

**Acceptance Criteria**
- AppCoordinator conforms to AppProtocol
- ServiceRegistry resolves all service dependencies
- ViewModelRegistry provides view models to views
- Error handling coordinator logs errors

**Dependencies**
_None_
### ✅ Configure OSLog subsystem and file logging (1-2 hours)

Set up logging categories (networking, inference, metal, storage, lifecycle) with file persistence

**Acceptance Criteria**
- Logs write to ~/Library/Logs/EchoCorePro/
- All 5 categories emit to correct subsystem
- Log levels switch between debug and release
- 30-day retention policy implemented

**Dependencies**
- Create Xcode project and app structure

## Local HTTP Server
**Goal:** Build localhost-only HTTP server for inter-process communication

### ✅ Implement HTTPServer lifecycle management (3-4 hours)

Create HTTPServer with start(port:) and stop() methods using Network.framework

**Acceptance Criteria**
- Server binds exclusively to 127.0.0.1
- Server starts on specified port
- Graceful shutdown on stop()
- Port conflict detection and handling

**Dependencies**
_None_
### ✅ Build request Router with route registration (2-3 hours)

Create Router with register(route:, handler:) and request-to-handler dispatch

**Acceptance Criteria**
- Routes register dynamically
- Requests match correct handlers
- 405 returned for unsupported methods
- 404 returned for unregistered routes

**Dependencies**
- Implement HTTPServer lifecycle management
### ✅ Implement JSON request/response serialization (2-3 hours)

Create RequestHandler with JSON parsing and response formatting

**Acceptance Criteria**
- Request body parses to Codable types
- Responses serialize with proper content-type
- Error responses follow {error, code, details} schema
- Base64 audio data handled correctly

**Dependencies**
- Build request Router with route registration
### ✅ Add WebSocket support for streaming responses (4-5 hours)

Implement WebSocket upgrade and message streaming for real-time updates

**Acceptance Criteria**
- WebSocket connections upgrade from HTTP
- Messages stream to connected clients
- Connections close cleanly on shutdown
- Ping/pong keep-alive implemented

**Dependencies**
- Implement JSON request/response serialization

## Data Persistence
**Goal:** Implement SwiftData models and data store layer

### ✅ Define SwiftData @Model schemas (2-3 hours)

Create LocalModelEntity, DownloadJobEntity, QuantizationJobEntity, ProcessingHistoryEntity, UserSettingsEntity, HotkeyEntity

**Acceptance Criteria**
- All 6 entities defined with @Model
- Relationships configured correctly
- Enums: ModelType, DownloadStatus, JobStatus, QuantizationType, ProcessingType, HotkeyAction
- Default values and constraints applied

**Dependencies**
_None_
### ✅ Implement DataStore with CRUD operations (2-3 hours)

Create DataStore protocol with save(_:), fetch(_:), delete(_:) using SwiftData

**Acceptance Criteria**
- save() persists entities to disk
- fetch() returns filtered results
- delete() removes entities
- Parameterized predicates prevent injection

**Dependencies**
- Define SwiftData @Model schemas
### ✅ Implement ModelRepository and DownloadQueue (3-4 hours)

Create ModelRepository for model metadata and DownloadQueue for job management

**Acceptance Criteria**
- ModelRepository: fetch(), save(), delete() working
- DownloadQueue: enqueue(), pause(), resume() working
- Queue persists across app restarts
- Max queue size enforced (503 when full)

**Dependencies**
- Implement DataStore with CRUD operations

## Network & Downloads
**Goal:** Build HTTP download system with progress tracking and resume capability

### ✅ Implement DownloadManager with URLSession (3-4 hours)

Create DownloadManager with startDownload(), pause(), resume(), cancel() using URLSession background tasks

**Acceptance Criteria**
- Downloads start from URL
- Pause/resume with Range headers
- Cancel terminates immediately
- Max 4 concurrent downloads enforced

**Dependencies**
_None_
### ✅ Implement ProgressTracker with Combine publishers (2-3 hours)

Create ProgressTracker with report(progress:, for:) and publisher for UI updates

**Acceptance Criteria**
- Progress updates publish on Combine subject
- Multiple downloads tracked independently
- ETA calculated from throughput
- Bytes downloaded and total bytes accurate

**Dependencies**
- Implement DownloadManager with URLSession
### ✅ Implement network reachability monitoring (2-3 hours)

Add Network.framework reachability observer for connection state changes

**Acceptance Criteria**
- Reachability state publishes via Combine
- Downloads pause on network loss
- Downloads auto-resume on network restore
- User notified of network issues

**Dependencies**
- Implement ProgressTracker with Combine publishers
### ✅ Implement repository whitelist validation (1-2 hours)

Restrict download sources to HuggingFace and GitHub URLs

**Acceptance Criteria**
- URLs validated against whitelist
- 422 returned for invalid domains
- URL scheme enforced (HTTPS only)
- Query params and paths allowed

**Dependencies**
- Implement DownloadManager with URLSession
### ✅ Implement SHA-256 checksum verification (2-3 hours)

Validate downloaded model files with SHA-256 hashes

**Acceptance Criteria**
- SHA-256 computed for downloaded files
- Checksums fetched from model registry
- Mismatched files deleted with error
- Verification logged

**Dependencies**
- Implement repository whitelist validation

## Model Management UI
**Goal:** Build SwiftUI interface for browsing, downloading, and managing models

### ✅ Implement ModelListView with SwiftUI (3-4 hours)

Create model list view with .ultraThinMaterial and matchedGeometryEffect

**Acceptance Criteria**
- Models display in grid layout
- Model cards show name, type, size, quantized status
- Loading/unloaded status indicators
- Pull-to-refresh support

**Dependencies**
_None_
### ✅ Implement DownloadProgressView (2-3 hours)

Create progress view with animated progress bar, ETA, and pause/resume controls

**Acceptance Criteria**
- Circular or linear progress indicator
- Progress percentage and bytes displayed
- ETA countdown shown
- Pause/resume/cancel buttons work

**Dependencies**
- Implement ModelListView with SwiftUI
### ✅ Implement ModelListViewModel (2-3 hours)

Create ObservableObject view model with Combine publishers for model state

**Acceptance Criteria**
- Models fetched from ModelRepository
- Download progress updates via Combine
- Error state exposed to view
- Load/unload actions work

**Dependencies**
- Implement DownloadProgressView
### ✅ Implement model detail sheet (2-3 hours)

Add detail view showing model metadata, version, and quantization options

**Acceptance Criteria**
- Sheet presents on model selected
- Details: name, type, version, size, last used
- Quantization options (int4, int8, fp16)
- Load/unload toggle

**Dependencies**
- Implement ModelListViewModel

## Python Runtime Integration
**Goal:** Bundle Python runtime and execute quantization scripts

### ✅ Bundle Python runtime with app (3-4 hours)

Package Python framework or embedding build within app bundle

**Acceptance Criteria**
- Python runtime included in app bundle
- Environment isolated from system Python
- Path variables configured correctly
- Runtime loads on first quantization request

**Dependencies**
_None_
### ✅ Implement PythonExecutor (2-3 hours)

Create execute(script:, args:) and execute(file:, args:) with subprocess management

**Acceptance Criteria**
- Python scripts execute in subprocess
- stdout/stderr captured to logs
- Exit codes returned
- Processes terminate on timeout

**Dependencies**
- Bundle Python runtime with app
### ✅ Implement EnvironmentManager (2-3 hours)

Create setup() and cleanup() for virtual environment and package isolation

**Acceptance Criteria**
- Virtual environment created on setup
- Packages installed in isolation
- Cleanup removes temp files
- Environment persists between runs

**Dependencies**
- Implement PythonExecutor
### ✅ Implement filesystem sandboxing for quantization (2-3 hours)

Restrict subprocess filesystem access to model directories only

**Acceptance Criteria**
- Subprocess uses restricted working directory
- Parent directory access blocked
- Symlink escapes prevented
- Violations logged and blocked

**Dependencies**
- Implement EnvironmentManager

## Model Quantization
**Goal:** Implement model quantization pipeline (int4, int8, fp16)

### ✅ Implement QuantizationManager (3-4 hours)

Create start(model:, type:) and getStatus(jobId:) with job queue

**Acceptance Criteria**
- Jobs queue for processing
- Status returns: queued, processing, completed, failed
- Progress tracked 0-100%
- Estimated duration calculated

**Dependencies**
_None_
### ✅ Create quantization Python script (4-5 hours)

Write Python script for model quantization using torch/transformers

**Acceptance Criteria**
- Script accepts model path, quantization type, output path
- int4, int8, fp16 quantization supported
- Progress output to stdout for parsing
- Errors returned with exit codes

**Dependencies**
- Implement QuantizationManager
### ✅ Implement quantization job persistence (2-3 hours)

Save/load quantization jobs to SwiftData with progress state

**Acceptance Criteria**
- Jobs persist across app restarts
- In-progress jobs resume on launch
- Completed jobs show history
- Failed jobs retain error messages

**Dependencies**
- Create quantization Python script

## Inference Engine
**Goal:** Build CoreML-based inference for STT and TTS

### ✅ Implement InferenceEngine with model loading (4-5 hours)

Create load(model:), unload(model:) using CoreML model loading

**Acceptance Criteria**
- CoreML models load from .mlmodelc files
- Load status tracked per model
- Memory tracked per loaded model
- Unload releases memory

**Dependencies**
_None_
### ✅ Implement InferenceQueue (2-3 hours)

Create enqueue(request:) and dequeue() with priority handling

**Acceptance Criteria**
- Requests queue FIFO
- Queue depth limit enforced
- 503 returned when queue full
- Priority requests (hotkeys) jump queue

**Dependencies**
- Implement InferenceEngine with model loading
### ✅ Implement ResourceManager (2-3 hours)

Create allocateMemory(size:), releaseMemory(id:) with threshold-based unloading

**Acceptance Criteria**
- Memory allocation tracked per model
- Inactive models unload when threshold exceeded
- User-defined memory limit respected
- Memory warnings trigger unload

**Dependencies**
- Implement InferenceQueue
### ✅ Implement STT inference endpoint (4-5 hours)

POST /api/inference/stt with audio data, returns transcription with confidence

**Acceptance Criteria**
- Accepts base64 PCM audio
- Returns text, confidence, processing time
- 400 for invalid audio format
- 404 if model not loaded
- Target <500ms latency

**Dependencies**
- Implement ResourceManager
### ✅ Implement TTS inference endpoint (4-5 hours)

POST /api/inference/tts with text, returns audio data

**Acceptance Criteria**
- Accepts text, model_id, voice, speed
- Returns base64 PCM audio
- 400 for text too long
- Duration and processing time in response

**Dependencies**
- Implement STT inference endpoint

## Audio Processing with Metal
**Goal:** Implement Metal-accelerated audio post-processing (de-essing, EQ)

### ✅ Implement MetalProcessor base (3-4 hours)

Create Metal command queue, compute pipeline, and texture management

**Acceptance Criteria**
- Metal device initialized
- Command queue created
- Compute shaders compile and cache
- Textures allocated for audio buffers

**Dependencies**
_None_
### ✅ Implement de-essing Metal shader (4-5 hours)

Write Metal compute shader for spectral de-essing

**Acceptance Criteria**
- Shader detects sibilance frequencies
- Gain reduction applied smoothly
- Processing time <10ms for 1s audio
- Parameters: threshold, ratio

**Dependencies**
- Implement MetalProcessor base
### ✅ Implement EQ Metal shader (4-5 hours)

Write Metal compute shader for parametric EQ

**Acceptance Criteria**
- Bands: low, low-mid, high-mid, high
- Gain +/- 12dB per band
- Q factor adjustable
- Linear-phase processing

**Dependencies**
- Implement MetalProcessor base
### ✅ Implement AudioPipeline (2-3 hours)

Create process(audio:, operations:) chaining de-ess and EQ

**Acceptance Criteria**
- Operations execute in order
- Multiple operations per request
- Processing time tracked
- Sample rate conversion if needed

**Dependencies**
- Implement de-essing Metal shader
- Implement EQ Metal shader
### ✅ Implement /api/audio/process endpoint (2-3 hours)

HTTP endpoint accepting audio data and operation list

**Acceptance Criteria**
- POST with operations array
- Returns processed audio base64
- 400 for invalid operation
- 422 for invalid parameters

**Dependencies**
- Implement AudioPipeline

## Waveform Visualization
**Goal:** Build Metal-accelerated waveform visualizer

### ✅ Implement WaveformRenderer (4-5 hours)

Create generateTexture(from:, width:, height:) using Metal compute

**Acceptance Criteria**
- Waveform renders to Metal texture
- 60fps for 60+ minute files
- Amplitude normalized to height
- Color gradient support

**Dependencies**
_None_
### ✅ Implement WaveformVisualizer SwiftUI view (3-4 hours)

Create SwiftUI view displaying Metal texture with .ultraThinMaterial

**Acceptance Criteria**
- View renders waveform smoothly
- Zoom/pan gestures supported
- Playback position indicator
- Real-time updates during recording

**Dependencies**
- Implement WaveformRenderer
### ✅ Add waveform to recording and playback views (2-3 hours)

Integrate waveform visualizer into audio recording and TTS playback

**Acceptance Criteria**
- Waveform updates in real-time during recording
- Playback position visible
- Regions highlighted for processing
- matchedGeometryEffect for transitions

**Dependencies**
- Implement WaveformVisualizer SwiftUI view

## Hotkey System
**Goal:** Implement global hotkey registration and monitoring

### ✅ Implement HotkeyManager (3-4 hours)

Create register(key:, action:), unregister(id:), enable(), disable()

**Acceptance Criteria**
- Hotkeys register system-wide
- Multiple hotkeys supported
- 409 for duplicate registration
- Enable/disable toggles monitoring

**Dependencies**
_None_
### ✅ Implement EventMonitor (3-4 hours)

Create startMonitoring(), stopMonitoring() using Carbon/NSEvent

**Acceptance Criteria**
- Global key events captured
- App-specific filtering works
- Modifiers tracked (Cmd, Option, Shift, Control)
- Monitoring stops cleanly

**Dependencies**
- Implement HotkeyManager
### ✅ Implement /api/hotkeys/register endpoint (2-3 hours)

HTTP endpoint for hotkey registration with app filtering

**Acceptance Criteria**
- POST registers hotkey
- app_filter restricts to specific apps
- Returns hotkey_id
- 422 for invalid key combination

**Dependencies**
- Implement EventMonitor
### ✅ Implement hotkey settings UI (3-4 hours)

SwiftUI view for registering and managing hotkeys

**Acceptance Criteria**
- List of registered hotkeys
- Add new hotkey with recorder
- Delete hotkey
- Toggle enable/disable

**Dependencies**
- Implement /api/hotkeys/register endpoint
### ✅ Request system accessibility permission (1-2 hours)

Prompt user for accessibility permission for global hotkeys

**Acceptance Criteria**
- Permission dialog shown on first use
- Graceful fallback if denied
- Status shown in settings
- Help link to System Preferences

**Dependencies**
- Implement HotkeyManager

## Settings & Preferences
**Goal:** Build settings UI and persistence layer

### ✅ Implement SettingsViewModel (2-3 hours)

Create ObservableObject for app settings with Combine publishers

**Acceptance Criteria**
- Default model selection
- Auto-quantize toggle
- Memory limit slider
- Hotkeys enabled toggle
- Download location picker

**Dependencies**
_None_
### ✅ Implement SettingsView (2-3 hours)

SwiftUI settings view with .ultraThinMaterial styling

**Acceptance Criteria**
- Sectioned layout (General, Models, Audio, Hotkeys)
- Form controls for all settings
- Validation feedback
- Reset to defaults button

**Dependencies**
- Implement SettingsViewModel
### ✅ Implement /api/settings endpoints (1-2 hours)

GET and PUT endpoints for reading and updating settings

**Acceptance Criteria**
- GET returns all settings
- PUT updates specific settings
- 422 for invalid values
- Settings persist to SwiftData

**Dependencies**
- Implement SettingsViewModel

## Inference UI & Recording
**Goal:** Build user interface for voice recording and text-to-speech playback

### ✅ Implement InferenceViewModel (2-3 hours)

Create ObservableObject coordinating recording, STT, and TTS

**Acceptance Criteria**
- Recording state managed
- STT results published
- TTS playback coordinated
- Error handling

**Dependencies**
_None_
### ✅ Implement recording view with microphone input (3-4 hours)

SwiftUI view with AVAudioEngine recording and waveform

**Acceptance Criteria**
- Recording toggle button
- Real-time waveform display
- Recording duration timer
- Audio level meter

**Dependencies**
- Implement InferenceViewModel
### ✅ Implement transcription result view (2-3 hours)

Display STT results with confidence and editing capability

**Acceptance Criteria**
- Transcribed text displayed
- Confidence indicator
- Text editable
- Copy to clipboard button

**Dependencies**
- Implement recording view with microphone input
### ✅ Implement TTS input view (2-3 hours)

Text input with voice selection and playback controls

**Acceptance Criteria**
- Multiline text input
- Voice picker dropdown
- Speed slider
- Play/pause/stop controls

**Dependencies**
- Implement transcription result view

## Polish & Animations
**Goal:** Refine UI with animations, transitions, and performance optimizations

### ✅ Add matchedGeometryEffect transitions (2-3 hours)

Implement smooth transitions between views using matchedGeometryEffect

**Acceptance Criteria**
- Hero animations for model cards
- Smooth sheet presentations
- No jarring layout shifts
- 60fps animations

**Dependencies**
_None_
### ✅ Implement loading and skeleton states (2-3 hours)

Add skeleton views and loading indicators throughout the app

**Acceptance Criteria**
- Skeleton screens for model list
- Spinners for async operations
- Progress bars for downloads
- Graceful placeholder content

**Dependencies**
- Add matchedGeometryEffect transitions
### ✅ Implement haptic feedback (1-2 hours)

Add haptic feedback for key interactions

**Acceptance Criteria**
- Haptic on button press
- Notification haptic on completion
- Error haptic on failures
- Subtle feedback for hotkeys

**Dependencies**
- Add matchedGeometryEffect transitions
### ✅ Optimize Metal shader compilation caching (2-3 hours)

Cache compiled Metal shaders to avoid first-launch delay

**Acceptance Criteria**
- Shaders compile on first launch
- Cached shaders load on subsequent launches
- Cache invalidation on app update
- Fallback if cache corrupt

**Dependencies**
_None_
### ✅ Implement Instruments signposts (1-2 hours)

Add signpost intervals for performance tracing

**Acceptance Criteria**
- Model loading signposts
- Quantization job signposts
- Download operation signposts
- Inference latency tracking

**Dependencies**
_None_

## Testing
**Goal:** Implement unit, integration, and E2E tests

### ✅ Write ViewModel unit tests (3-4 hours)

Test state transitions with Combine expectations

**Acceptance Criteria**
- ModelListViewModel tests pass
- DownloadViewModel tests pass
- SettingsViewModel tests pass
- Error state tests pass

**Dependencies**
_None_
### ✅ Write SwiftData CRUD tests (2-3 hours)

Test data operations with in-memory container

**Acceptance Criteria**
- save() tests pass
- fetch() with predicates tests pass
- delete() tests pass
- Relationship tests pass

**Dependencies**
_None_
### ✅ Write HTTP server integration tests (3-4 hours)

Test request/response cycles with mock server

**Acceptance Criteria**
- All endpoints tested
- Error responses validated
- WebSocket tests pass
- Serialization tests pass

**Dependencies**
_None_
### ✅ Write Metal shader unit tests (3-4 hours)

Test shaders with mock textures

**Acceptance Criteria**
- De-ess shader output validated
- EQ shader output validated
- Edge cases handled
- Performance tests pass

**Dependencies**
_None_
### ✅ Write E2E UI tests with XCTest UI (4-5 hours)

Test user flows with XCTest UI framework

**Acceptance Criteria**
- Download flow test passes
- Model load/unload test passes
- Settings navigation test passes
- Hotkey registration test passes

**Dependencies**
_None_

## ❓ Open Questions
- Specific model format requirements for CoreML conversion
- Maximum app bundle size constraint for distribution
- Preferred deployment method (Mac App Store vs direct download)
- Specific quantization libraries and versions to bundle