//
//  EchoCoreProApp.swift
//  EchoCorePro
//
//  A high-performance local voice server for macOS
//

import SwiftUI
import SwiftData

/// Main entry point for EchoCore Pro application
@main
struct EchoCoreProApp: App {
    /// App coordinator managing lifecycle and dependencies
    @StateObject private var coordinator = AppCoordinator()
    
    /// SwiftData model container for persistence
    let modelContainer: ModelContainer
    
    init() {
        // Initialize SwiftData model container with all required schemas
        do {
            let schema = Schema([
                LocalModelEntity.self,
                DownloadJobEntity.self,
                UserSettingsEntity.self,
                ProcessingHistoryEntity.self,
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        
        // Initialize logging system
        OSLogManager.shared.log("EchoCorePro app initializing", category: .lifecycle, level: .info)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .environment(\.serviceRegistry, coordinator.serviceRegistry)
                .environment(\.viewModelRegistry, coordinator.viewModelRegistry)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 900, height: 650)
        
        // Menu bar controls
        MenuBarExtra("EchoCore Pro", systemImage: "waveform") {
            MenuBarView()
                .environmentObject(coordinator)
        }
        .menuBarExtraStyle(.window)
        
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(coordinator)
        }
    }
}

/// Main content view
struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var selectedTab: SidebarTab = .models
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            // Main content area based on selected tab
            switch selectedTab {
            case .models:
                ModelListView()
            case .recording:
                RecordingView()
            case .voiceCloning:
                VoiceCloningView()
            case .processing:
                ProcessingPlaceholder()
            case .history:
                HistoryPlaceholder()
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .background(.ultraThinMaterial)
    }
}

/// Sidebar navigation tabs
enum SidebarTab: String, CaseIterable, Identifiable {
    case models = "Models"
    case recording = "Recording"
    case voiceCloning = "Voice Cloning"
    case processing = "Processing"
    case history = "History"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .models: return "square.stack.3d.up"
        case .recording: return "mic"
        case .voiceCloning: return "person.wave.2.fill"
        case .processing: return "waveform.badge.magnifyingglass"
        case .history: return "clock"
        }
    }
}

/// Sidebar navigation view
struct SidebarView: View {
    @Binding var selectedTab: SidebarTab
    
    var body: some View {
        List(SidebarTab.allCases, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .navigationTitle("EchoCore Pro")
    }
}

// MARK: - Placeholder Views

struct ProcessingPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Audio Processing")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Metal-accelerated de-essing and EQ coming soon")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

struct HistoryPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Processing History")
                .font(.title2)
                .fontWeight(.semibold)
            Text("View past transcriptions and audio processing")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

/// Menu bar view for quick access
struct MenuBarView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EchoCore Pro")
                .font(.headline)
            Divider()
            Button("Start Recording") {
                // TODO: Implement recording
            }
            Button("Stop Recording") {
                // TODO: Implement stop recording
            }
            Divider()
            Button("Open Main Window") {
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding()
        .frame(width: 200)
    }
}

/// Settings view placeholder
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            ModelsSettingsView()
                .tabItem {
                    Label("Models", systemImage: "square.stack.3d.up")
                }
            AudioSettingsView()
                .tabItem {
                    Label("Audio", systemImage: "speaker.wave.3")
                }
            HotkeysSettingsView()
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Text("General Settings")
                .font(.headline)
            Text("Configure general application preferences")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct ModelsSettingsView: View {
    var body: some View {
        Form {
            Text("Model Settings")
                .font(.headline)
            Text("Configure model download and quantization preferences")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct AudioSettingsView: View {
    var body: some View {
        Form {
            Text("Audio Settings")
                .font(.headline)
            Text("Configure audio processing preferences")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct HotkeysSettingsView: View {
    var body: some View {
        Form {
            Text("Hotkey Settings")
                .font(.headline)
            Text("Configure global keyboard shortcuts")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
