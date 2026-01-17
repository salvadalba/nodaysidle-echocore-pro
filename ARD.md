# Architecture Requirements Document

## 🧱 System Overview
EchoCore Pro is a native macOS voice server application that runs entirely on-device. The architecture consists of a SwiftUI frontend for model management and audio processing, a local inference engine powered by CoreML/NaturalLanguage frameworks, Metal-accelerated audio post-processing, and SwiftData for local persistence. No network or server components required after initial model downloads.

## 🏗 Architecture Style
Desktop application with local-first architecture, leveraging macOS-specific frameworks for optimal performance on Apple Silicon.

## 🎨 Frontend Architecture
- **Framework:** SwiftUI with .ultraThinMaterial glassmorphism design system
- **State Management:** Combine framework for reactive data flow across view models
- **Routing:** NavigationStack and NavigationSplitView for hierarchical navigation
- **Build Tooling:** Xcode project with native Swift compilation, Metal shader compilation

## 🧠 Backend Architecture
- **Approach:** Local background processes using Actor-based concurrency for model inference
- **API Style:** Local HTTP server on localhost for inter-process communication
- **Services:**
- ModelDownloadService - handles fetching models from remote repositories
- QuantizationService - converts models to optimized formats for Apple Silicon
- InferenceEngine - runs CoreML/NaturalLanguage models for speech processing
- AudioProcessingPipeline - Metal-accelerated de-essing and EQ
- HotkeyService - AppKit-based global keyboard shortcuts

## 🗄 Data Layer
- **Primary Store:** SwiftData for models, processing history, and user preferences
- **Relationships:** Model-to-ProcessingHistory one-to-many, UserSettings singleton
- **Migrations:** SwiftData automatic schema migrations with versioned models

## ☁️ Infrastructure
- **Hosting:** Standalone macOS app bundle (.app) distributed directly or via Mac App Store
- **Scaling Strategy:** Single-device, utilizing multi-core CPUs and GPU via Metal for parallel processing
- **CI/CD:** GitHub Actions or Xcode Cloud for automated builds and testing

## ⚖️ Key Trade-offs
- macOS-only enables deep framework integration but limits cross-platform reach
- Local-first ensures privacy but requires significant local storage for models
- Bundled Python runtime increases app size vs. requiring user installation
- Metal-only optimization leverages Apple Silicon but excludes Intel Macs

## 📐 Non-Functional Requirements
- Sub-500ms inference latency on M1/M2/M3 chips
- Memory efficiency: background operations under 2GB RAM
- 60fps UI animations with matchedGeometryEffect transitions
- Support for macOS 14+ (Sonoma) for latest SwiftUI/Metal features
- Graceful download management with pause/resume capabilities