import SwiftUI
import SwiftData
import AppKit

// MARK: - Menu Bar Manager

/// Manages the macOS menu bar integration
@MainActor
final class MenuBarManager: ObservableObject {
    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    @Published var isPopoverShown = false

    private let settings: AppSettings
    private let dataStore: DataStore
    private let clipboardMonitor: ClipboardMonitor

    // MARK: - Initialization

    init(settings: AppSettings, dataStore: DataStore, clipboardMonitor: ClipboardMonitor) {
        self.settings = settings
        self.dataStore = dataStore
        self.clipboardMonitor = clipboardMonitor

        setupStatusItem()
        setupEventMonitor()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard Manager")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupEventMonitor() {
        // Close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.isPopoverShown == true {
                self?.hidePopover()
            }
        }
    }

    // MARK: - Popover Management

    @objc func togglePopover() {
        if isPopoverShown {
            hidePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem?.button else { return }

        if popover == nil {
            popover = NSPopover()
            popover?.contentSize = NSSize(width: 400, height: 500)
            popover?.behavior = .transient
            popover?.animates = true

            let contentView = ClipboardHistoryView(
                dataStore: dataStore,
                settings: settings,
                clipboardMonitor: clipboardMonitor,
                onDismiss: { [weak self] in
                    self?.hidePopover()
                }
            )

            popover?.contentViewController = NSHostingController(rootView: contentView)
        }

        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isPopoverShown = true

        // Focus the search field
        NSApp.activate(ignoringOtherApps: true)
    }

    func hidePopover() {
        popover?.performClose(nil)
        isPopoverShown = false
    }

    // MARK: - Cleanup

    func cleanup() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        statusItem = nil
    }
}

// MARK: - Clipboard History View

struct ClipboardHistoryView: View {
    // MARK: - Properties

    @ObservedObject var dataStore: DataStore
    let settings: AppSettings
    let clipboardMonitor: ClipboardMonitor
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedItemID: UUID?
    @State private var items: [ClipboardItem] = []
    @State private var isLoading = true
    @State private var showingClearConfirmation = false

    @FocusState private var isSearchFocused: Bool

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar

            Divider()

            // Content
            if isLoading {
                loadingView
            } else if items.isEmpty {
                emptyView
            } else {
                itemsList
            }

            Divider()

            // Footer
            footerBar
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await loadItems()
        }
        .onChange(of: searchText) { _, newValue in
            Task {
                await search(query: newValue)
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search clipboard history...", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit {
                    pasteSelectedItem()
                }

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }

    // MARK: - Items List

    private var itemsList: some View {
        ScrollViewReader { proxy in
            List(selection: $selectedItemID) {
                // Pinned section
                if !pinnedItems.isEmpty {
                    Section("Pinned") {
                        ForEach(pinnedItems) { item in
                            ClipboardItemRow(
                                item: item,
                                settings: settings,
                                isSelected: selectedItemID == item.id,
                                onPaste: { pasteItem(item) },
                                onPin: { togglePin(item) },
                                onDelete: { deleteItem(item) }
                            )
                            .tag(item.id)
                        }
                    }
                }

                // Recent section
                Section("Recent") {
                    ForEach(recentItems) { item in
                        ClipboardItemRow(
                            item: item,
                            settings: settings,
                            isSelected: selectedItemID == item.id,
                            onPaste: { pasteItem(item) },
                            onPin: { togglePin(item) },
                            onDelete: { deleteItem(item) }
                        )
                        .tag(item.id)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onKeyPress(.upArrow) {
                selectPrevious()
                return .handled
            }
            .onKeyPress(.downArrow) {
                selectNext()
                return .handled
            }
            .onKeyPress(.return) {
                pasteSelectedItem()
                return .handled
            }
            .onKeyPress(.delete) {
                deleteSelectedItem()
                return .handled
            }
            .onChange(of: selectedItemID) { _, newID in
                if let id = newID {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            if searchText.isEmpty {
                Text("No clipboard history")
                    .font(.headline)
                Text("Copy something to get started")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No results found")
                    .font(.headline)
                Text("Try a different search term")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            Text("\(dataStore.itemCount) items")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: { showingClearConfirmation = true }) {
                Text("Clear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Button(action: openSettings) {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .alert("Clear History", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearHistory()
            }
        } message: {
            Text("Are you sure you want to clear your clipboard history? Pinned items will be kept.")
        }
    }

    // MARK: - Computed Properties

    private var pinnedItems: [ClipboardItem] {
        items.filter { $0.isPinned }
    }

    private var recentItems: [ClipboardItem] {
        items.filter { !$0.isPinned }
    }

    // MARK: - Actions

    private func loadItems() async {
        isLoading = true
        do {
            items = try dataStore.getAllItems()
            if let first = items.first {
                selectedItemID = first.id
            }
        } catch {
            print("Failed to load items: \(error)")
        }
        isLoading = false
    }

    private func search(query: String) async {
        if query.isEmpty {
            await loadItems()
        } else {
            do {
                items = try dataStore.search(query: query, mode: settings.searchMode)
                if let first = items.first {
                    selectedItemID = first.id
                }
            } catch {
                print("Search failed: \(error)")
            }
        }
    }

    private func pasteItem(_ item: ClipboardItem, removeFormatting: Bool = false) {
        // Write to clipboard
        clipboardMonitor.writeToClipboard(item, removeFormatting: removeFormatting || settings.removeFormattingByDefault)

        // Mark as pasted
        try? dataStore.markAsPasted(item)

        // Dismiss
        onDismiss()

        // Auto-paste if enabled
        if settings.pasteAutomatically {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                clipboardMonitor.simulatePaste()
            }
        }
    }

    private func pasteSelectedItem() {
        guard let id = selectedItemID,
              let item = items.first(where: { $0.id == id }) else { return }
        pasteItem(item)
    }

    private func togglePin(_ item: ClipboardItem) {
        try? dataStore.togglePin(item)
        Task {
            await loadItems()
        }
    }

    private func deleteItem(_ item: ClipboardItem) {
        try? dataStore.deleteItem(item)
        Task {
            await loadItems()
        }
    }

    private func deleteSelectedItem() {
        guard let id = selectedItemID,
              let item = items.first(where: { $0.id == id }) else { return }
        deleteItem(item)
    }

    private func selectNext() {
        guard let currentID = selectedItemID,
              let currentIndex = items.firstIndex(where: { $0.id == currentID }),
              currentIndex < items.count - 1 else { return }
        selectedItemID = items[currentIndex + 1].id
    }

    private func selectPrevious() {
        guard let currentID = selectedItemID,
              let currentIndex = items.firstIndex(where: { $0.id == currentID }),
              currentIndex > 0 else { return }
        selectedItemID = items[currentIndex - 1].id
    }

    private func clearHistory() {
        try? dataStore.clearHistory(keepPinned: true)
        Task {
            await loadItems()
        }
    }

    private func openSettings() {
        onDismiss()
        // Open settings window
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}

// MARK: - Clipboard Item Row

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let settings: AppSettings
    let isSelected: Bool
    let onPaste: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            typeIcon
                .frame(width: 24)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayText)
                    .lineLimit(settings.showPreview ? 2 : 1)
                    .font(.system(.body, design: .default))

                if settings.showSourceApp, let appName = item.sourceAppName {
                    HStack(spacing: 4) {
                        Text(appName)
                        Text("•")
                        Text(item.copiedAt.formatted(.relative(presentation: .named)))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Actions
            if isHovering || isSelected {
                HStack(spacing: 8) {
                    Button(action: onPin) {
                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(item.isPinned ? .accentColor : .secondary)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }

            // Pin indicator
            if item.isPinned && !isHovering && !isSelected {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }

            // Sensitive indicator
            if item.isSensitive {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            onPaste()
        }
        .onTapGesture(count: 1) {
            // Single tap selects
        }
    }

    @ViewBuilder
    private var typeIcon: some View {
        switch item.contentType {
        case .plainText:
            Image(systemName: "text.alignleft")
                .foregroundColor(.secondary)
        case .rtf, .html:
            Image(systemName: "text.badge.star")
                .foregroundColor(.blue)
        case .image, .png, .tiff, .jpeg:
            if let imageData = item.imageData,
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.green)
            }
        case .pdf:
            Image(systemName: "doc.richtext")
                .foregroundColor(.red)
        case .fileURL:
            Image(systemName: "folder")
                .foregroundColor(.blue)
        case .url:
            Image(systemName: "link")
                .foregroundColor(.purple)
        case .color:
            Image(systemName: "paintpalette")
                .foregroundColor(.orange)
        case .unknown:
            Image(systemName: "questionmark.square")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let showClipboardHistory = Notification.Name("showClipboardHistory")
}
