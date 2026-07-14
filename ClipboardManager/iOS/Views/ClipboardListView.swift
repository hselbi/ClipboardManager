import SwiftUI
import SwiftData

// MARK: - iOS Clipboard List View

struct ClipboardListView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.copiedAt, order: .reverse) private var items: [ClipboardItem]

    @ObservedObject var clipboardHandler: iOSClipboardHandler
    @ObservedObject var settings: AppSettings

    @State private var searchText = ""
    @State private var showingSettings = false
    @State private var showingClearConfirmation = false
    @State private var selectedItem: ClipboardItem?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if items.isEmpty && searchText.isEmpty {
                    emptyStateView
                } else {
                    listView
                }

                // Paste permission banner
                if clipboardHandler.showingPastePermissionAlert {
                    pastePermissionBanner
                }
            }
            .navigationTitle("Clipboard")
            .searchable(text: $searchText, prompt: "Search history")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: captureClipboard) {
                            Label("Capture Clipboard", systemImage: "arrow.down.doc")
                        }

                        Divider()

                        Button(role: .destructive, action: { showingClearConfirmation = true }) {
                            Label("Clear History", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                iOSSettingsView(settings: settings)
            }
            .sheet(item: $selectedItem) { item in
                ItemDetailView(item: item, onPaste: { pasteItem(item) })
            }
            .alert("Clear History", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearHistory()
                }
            } message: {
                Text("Are you sure you want to clear your clipboard history? Pinned items will be kept.")
            }
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            // Pinned section
            if !pinnedItems.isEmpty {
                Section("Pinned") {
                    ForEach(pinnedItems) { item in
                        ClipboardItemCell(
                            item: item,
                            settings: settings,
                            onTap: { selectedItem = item },
                            onCopy: { copyItem(item) }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteItem(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                togglePin(item)
                            } label: {
                                Label("Unpin", systemImage: "pin.slash")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }

            // Recent section
            Section("Recent") {
                ForEach(filteredRecentItems) { item in
                    ClipboardItemCell(
                        item: item,
                        settings: settings,
                        onTap: { selectedItem = item },
                        onCopy: { copyItem(item) }
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteItem(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            togglePin(item)
                        } label: {
                            Label("Pin", systemImage: "pin")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            captureClipboard()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Clipboard History", systemImage: "doc.on.clipboard")
        } description: {
            Text("Copy content or tap the capture button to save clipboard content")
        } actions: {
            Button(action: captureClipboard) {
                Text("Capture Clipboard")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Paste Permission Banner

    private var pastePermissionBanner: some View {
        VStack {
            Spacer()

            HStack {
                Image(systemName: "doc.on.clipboard.fill")
                    .foregroundColor(.white)

                Text("New content available")
                    .foregroundColor(.white)

                Spacer()

                Button("Save") {
                    captureClipboard()
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            .padding()
            .background(Color.accentColor)
            .cornerRadius(12)
            .padding()
        }
    }

    // MARK: - Computed Properties

    private var pinnedItems: [ClipboardItem] {
        items.filter { $0.isPinned }
    }

    private var filteredRecentItems: [ClipboardItem] {
        let recent = items.filter { !$0.isPinned }

        if searchText.isEmpty {
            return recent
        }

        return recent.filter { item in
            item.searchableText.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Actions

    private func captureClipboard() {
        clipboardHandler.captureCurrentClipboard()
    }

    private func copyItem(_ item: ClipboardItem) {
        clipboardHandler.writeToClipboard(item)
        item.markAsPasted()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func pasteItem(_ item: ClipboardItem) {
        copyItem(item)
        selectedItem = nil
    }

    private func togglePin(_ item: ClipboardItem) {
        item.togglePin()
    }

    private func deleteItem(_ item: ClipboardItem) {
        modelContext.delete(item)
    }

    private func clearHistory() {
        let nonPinned = items.filter { !$0.isPinned }
        for item in nonPinned {
            modelContext.delete(item)
        }
    }
}

// MARK: - Clipboard Item Cell

struct ClipboardItemCell: View {
    let item: ClipboardItem
    let settings: AppSettings
    let onTap: () -> Void
    let onCopy: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Type icon or image preview
                itemIcon
                    .frame(width: 44, height: 44)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayText)
                        .lineLimit(2)
                        .font(.body)
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Text(item.contentType.displayName)

                        Text("•")

                        Text(item.copiedAt.formatted(.relative(presentation: .abbreviated)))

                        if item.isSensitive {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Copy button
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var itemIcon: some View {
        Group {
            switch item.contentType {
            case .image, .png, .tiff, .jpeg:
                if let imageData = item.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .cornerRadius(8)
                        .clipped()
                } else {
                    iconView(systemName: "photo", color: .green)
                }
            case .plainText:
                iconView(systemName: "text.alignleft", color: .gray)
            case .rtf, .html:
                iconView(systemName: "text.badge.star", color: .blue)
            case .url:
                iconView(systemName: "link", color: .purple)
            case .fileURL:
                iconView(systemName: "folder", color: .blue)
            case .pdf:
                iconView(systemName: "doc.richtext", color: .red)
            case .color:
                iconView(systemName: "paintpalette", color: .orange)
            case .unknown:
                iconView(systemName: "questionmark.square", color: .gray)
            }
        }
    }

    private func iconView(systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))

            Image(systemName: systemName)
                .font(.title3)
                .foregroundColor(color)
        }
    }
}

// MARK: - Item Detail View

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let item: ClipboardItem
    let onPaste: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Preview
                    previewSection

                    Divider()

                    // Metadata
                    metadataSection

                    Divider()

                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)

            Group {
                if let imageData = item.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                } else if let text = item.text {
                    Text(text)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                }
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Information")
                .font(.headline)

            VStack(spacing: 8) {
                metadataRow(title: "Type", value: item.contentType.displayName)
                metadataRow(title: "Copied", value: item.copiedAt.formatted())
                metadataRow(title: "Size", value: ByteCountFormatter.string(fromByteCount: Int64(item.contentSize), countStyle: .file))
                metadataRow(title: "Paste Count", value: "\(item.pasteCount)")

                if let appName = item.sourceAppName {
                    metadataRow(title: "Source", value: appName)
                }

                if item.isPinned {
                    metadataRow(title: "Status", value: "Pinned")
                }

                if item.isSensitive {
                    metadataRow(title: "Security", value: "Sensitive Content")
                }
            }
        }
    }

    private func metadataRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: onPaste) {
                Label("Copy to Clipboard", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

// MARK: - iOS Settings View

struct iOSSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Stepper("Max History: \(settings.maxHistorySize)", value: $settings.maxHistorySize, in: 10...999)

                    Toggle("iCloud Sync", isOn: $settings.enableiCloudSync)

                    Toggle("Trim Whitespace", isOn: $settings.trimWhitespace)

                    Toggle("Ignore Duplicates", isOn: $settings.ignoreConsecutiveDuplicates)
                }

                Section("Privacy") {
                    Toggle("Detect Password Managers", isOn: $settings.enablePasswordManagerDetection)

                    Toggle("Clear on App Close", isOn: $settings.clearHistoryOnQuit)

                    NavigationLink("Ignored Patterns") {
                        IgnoredPatternsView(patterns: $settings.ignoredPatterns)
                    }
                }

                Section("Display") {
                    Toggle("Show Preview", isOn: $settings.showPreview)

                    Stepper("Preview Length: \(settings.previewMaxLength)", value: $settings.previewMaxLength, in: 50...500, step: 50)
                }

                Section("Storage") {
                    Toggle("Ignore Large Items", isOn: $settings.ignoreLargeItems)

                    if settings.ignoreLargeItems {
                        Picker("Size Limit", selection: $settings.largeItemThreshold) {
                            Text("1 MB").tag(1_000_000)
                            Text("5 MB").tag(5_000_000)
                            Text("10 MB").tag(10_000_000)
                        }
                    }
                }

                Section {
                    Button("Reset to Defaults") {
                        settings.resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Ignored Patterns View

struct IgnoredPatternsView: View {
    @Binding var patterns: [String]
    @State private var newPattern = ""

    var body: some View {
        List {
            Section {
                ForEach(patterns, id: \.self) { pattern in
                    Text(pattern)
                        .font(.system(.body, design: .monospaced))
                }
                .onDelete { indexSet in
                    patterns.remove(atOffsets: indexSet)
                }
            }

            Section("Add Pattern") {
                HStack {
                    TextField("Regex pattern", text: $newPattern)
                        .font(.system(.body, design: .monospaced))

                    Button("Add") {
                        if !newPattern.isEmpty {
                            patterns.append(newPattern)
                            newPattern = ""
                        }
                    }
                    .disabled(newPattern.isEmpty)
                }
            }
        }
        .navigationTitle("Ignored Patterns")
    }
}
