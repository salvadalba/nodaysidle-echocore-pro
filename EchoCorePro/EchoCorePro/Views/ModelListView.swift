//
//  ModelListView.swift
//  EchoCorePro
//
//  Main view for browsing and downloading voice models
//

import SwiftData
import SwiftUI

struct ModelListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalModelEntity.dateDownloaded, order: .reverse)
    private var localModels: [LocalModelEntity]

    @StateObject private var downloadManager = ModelDownloadManager()

    @State private var searchText = ""
    @State private var selectedType: ModelType? = nil
    @State private var selectedModel: AvailableModel?
    @State private var showingDeleteAlert = false
    @State private var modelToDelete: LocalModelEntity?
    @State private var errorMessage: String?

    private var filteredAvailableModels: [AvailableModel] {
        var models = ModelRegistry.availableModels

        // Filter out already downloaded models
        let downloadedIds = Set(localModels.compactMap { $0.huggingFaceId })
        models = models.filter { !downloadedIds.contains($0.id) }

        if let type = selectedType {
            models = models.filter { $0.type == type }
        }

        if !searchText.isEmpty {
            let lowercased = searchText.lowercased()
            models = models.filter {
                $0.name.lowercased().contains(lowercased)
                    || $0.description.lowercased().contains(lowercased)
            }
        }

        return models
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                filterBar
                    .padding()
                    .background(.ultraThinMaterial)

                // Content
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Active downloads section
                        if !downloadManager.activeDownloads.isEmpty {
                            activeDownloadsSection
                        }

                        // Downloaded models section
                        if !localModels.isEmpty {
                            downloadedModelsSection
                        }

                        // Available models section
                        availableModelsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Models")
            .searchable(text: $searchText, prompt: "Search models...")
            .sheet(item: $selectedModel) { model in
                ModelDetailSheet(model: model, downloadManager: downloadManager)
            }
            .alert("Delete Model", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let model = modelToDelete {
                        deleteModel(model)
                    }
                }
            } message: {
                Text(
                    "Are you sure you want to delete \(modelToDelete?.name ?? "this model")? This cannot be undone."
                )
            }
            .alert(
                "Error",
                isPresented: .init(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .onAppear {
                downloadManager.setModelContext(modelContext)
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: selectedType == nil,
                    action: { selectedType = nil }
                )

                ForEach(ModelType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.rawValue,
                        icon: type.icon,
                        isSelected: selectedType == type,
                        action: { selectedType = type }
                    )
                }

                Spacer()

                // Storage info
                Text(formatBytes(downloadManager.totalDownloadedSize()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Active Downloads Section

    private var activeDownloadsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Downloading")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                ProgressView()
                    .scaleEffect(0.6)
            }

            ForEach(Array(downloadManager.activeDownloads.values)) { download in
                DownloadProgressCard(download: download) {
                    Task {
                        await downloadManager.cancelDownload(id: download.id)
                    }
                }
            }
        }
    }

    // MARK: - Downloaded Models Section

    private var downloadedModelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Downloaded")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(localModels) { model in
                LocalModelCard(
                    model: model,
                    onDelete: {
                        modelToDelete = model
                        showingDeleteAlert = true
                    })
            }
        }
    }

    // MARK: - Available Models Section

    private var availableModelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available for Download")
                .font(.headline)
                .foregroundStyle(.secondary)

            if filteredAvailableModels.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("All models downloaded!")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                    ], spacing: 16
                ) {
                    ForEach(filteredAvailableModels) { model in
                        AvailableModelCard(model: model) {
                            selectedModel = model
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func deleteModel(_ model: LocalModelEntity) {
        do {
            try downloadManager.deleteModel(model)
        } catch {
            errorMessage = error.localizedDescription
        }
        modelToDelete = nil
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) + " used"
    }
}

// MARK: - Download Progress Card

struct DownloadProgressCard: View {
    let download: ModelDownloadManager.DownloadProgress
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(download.modelName)
                        .font(.headline)
                    Text(download.formattedProgress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ProgressView(value: download.progress)
                .progressViewStyle(.linear)
                .tint(.blue)

            HStack {
                Text("\(download.progressPercent)%")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Text(download.formattedETA)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Local Model Card

struct LocalModelCard: View {
    let model: LocalModelEntity
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: model.type.icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(.tint.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(model.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(model.sizeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if model.isQuantized, let qType = model.quantizationType {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(qType.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Status
            if model.isLoaded {
                Label("Loaded", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 8 : 4)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Available Model Card

struct AvailableModelCard: View {
    let model: AvailableModel
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: model.type.icon)
                        .font(.title2)
                        .foregroundStyle(.tint)

                    Spacer()

                    Text(model.sizeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Name & Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(model.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Download button
                HStack {
                    Label("Download", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.tint.opacity(0.1))
                .foregroundStyle(.tint)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
            .frame(minHeight: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(
                        color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 10 : 5)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Model Detail Sheet

struct ModelDetailSheet: View {
    let model: AvailableModel
    @ObservedObject var downloadManager: ModelDownloadManager
    @Environment(\.dismiss) private var dismiss
    @State private var isDownloading = false
    @State private var errorMessage: String?

    private var currentDownload: ModelDownloadManager.DownloadProgress? {
        downloadManager.activeDownloads.values.first { $0.modelId == model.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(model.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                        Text(model.description)
                            .foregroundStyle(.secondary)
                    }

                    // Details grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 16
                    ) {
                        DetailItem(title: "Type", value: model.type.rawValue, icon: model.type.icon)
                        DetailItem(
                            title: "Size", value: model.sizeFormatted, icon: "arrow.down.circle")
                        DetailItem(title: "Version", value: model.version, icon: "number")
                        DetailItem(
                            title: "Languages", value: model.languages.joined(separator: ", "),
                            icon: "globe")
                    }

                    // Download progress
                    if let download = currentDownload {
                        VStack(spacing: 8) {
                            ProgressView(value: download.progress)
                                .progressViewStyle(.linear)
                                .tint(.blue)

                            HStack {
                                Text("\(download.progressPercent)%")
                                    .font(.caption)
                                    .fontWeight(.medium)

                                Spacer()

                                Text(download.formattedProgress)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Error message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)

                Spacer()

                if currentDownload != nil {
                    Button {
                        if let download = currentDownload {
                            Task {
                                await downloadManager.cancelDownload(id: download.id)
                            }
                        }
                    } label: {
                        Label("Cancel Download", systemImage: "xmark.circle")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        startDownload()
                    } label: {
                        Label("Download Model", systemImage: "arrow.down.circle.fill")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDownloading)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .frame(width: 500, height: 500)
    }

    private func startDownload() {
        isDownloading = true
        errorMessage = nil

        Task {
            do {
                try await downloadManager.downloadModel(model)
            } catch {
                errorMessage = error.localizedDescription
            }
            isDownloading = false
        }
    }
}

struct DetailItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ModelListView()
        .frame(width: 800, height: 600)
}
