# Agent Prompts — EchoCore Pro
r
## 🧭 Global Rules

### ✅ Do
- Use SwiftUI for all UI with .ultraThinMaterial and matchedGeometryEffect
- Use SwiftData for persistence, CoreML for AI inference
- Bundle Python runtime locally, no external server dependencies
- Metal shaders for audio processing and waveform visualization
- Local-first: all processing on-device, no cloud services

### ❌ Don’t
- Do not create web servers or use web technologies
- Do not use cross-platform frameworks (native macOS only)
- Do not require network for core functionality
- Do not use alternative databases besides SwiftData/Core Data
- Do not introduce external AI APIs or cloud services

## 🧩 Task Prompts
## Foundation & Scaffolding

**Context**
Set up Xcode project, build infrastructure, and core application lifecycle with SwiftUI, SwiftData, and logging systems

### Universal Agent Prompt
```
ROLE: Expert macOS SwiftUI Engineer

GOAL: Initialize Xcode project with SwiftUI, configure bundle/signing/entitlements, implement AppCoordinator, ServiceRegistry, ViewModelRegistry, and OSLog file logging

CONTEXT: Set up Xcode project, build infrastructure, and core application lifecycle with SwiftUI, SwiftData, and logging systems

FILES TO CREATE:
- EchoCorePro/EchoCoreProApp.swift
- EchoCorePro/Coordinator/AppCoordinator.swift
- EchoCorePro/Coordinator/AppProtocol.swift
- EchoCorePro/Services/ServiceRegistry.swift
- EchoCorePro/ViewModels/ViewModelRegistry.swift
- EchoCorePro/Utilities/Logging/OSLogManager.swift

FILES TO MODIFY:
_None_

DETAILED STEPS:
1. Create Xcode macOS app project targeting macOS 14+, configure bundle identifier and code signing
2. Implement AppProtocol main entry point with AppCoordinator conforming to it
3. Create ServiceRegistry for dependency injection and ViewModelRegistry for view model providers
4. Set up OSLog subsystem with 5 categories: networking, inference, metal, storage, lifecycle
5. Configure file logging to ~/Library/Logs/EchoCorePro/ with 30-day retention

VALIDATION:
xcodebuild -scheme EchoCorePro -configuration Debug build
```
