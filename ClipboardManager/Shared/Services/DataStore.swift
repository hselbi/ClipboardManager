import Foundation
import SwiftData
import Combine

// MARK: - Data Store

/// Manages persistence of clipboard items using SwiftData with iCloud sync
@MainActor
final class DataStore: ObservableObject {
    // MARK: - Properties

    let modelContainer: ModelContainer
    let modelContext: ModelContext

    @Published private(set) var itemCount: Int = 0
    @Published private(set) var pinnedCount: Int = 0

    private let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()
    private var cleanupTimer: Timer?

    // MARK: - Initialization

    init(settings: AppSettings, inMemory: Bool = false) throws {
        self.settings = settings

        let schema = Schema([ClipboardItem.self])

        let configuration: ModelConfiguration

        if inMemory {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else if settings.enableiCloudSync {
            // iCloud sync enabled
            configuration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .automatic
            )
        } else {
            // Local only
            configuration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .none
            )
        }

        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        self.modelContext = modelContainer.mainContext
        self.modelContext.autosaveEnabled = true

        setupNotifications()
        setupCleanupTimer()
        updateCounts()
    }

    // MARK: - Setup

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .iCloudSyncSettingChanged)
            .sink { [weak self] _ in
                // Handle iCloud sync setting change
                // Note: This typically requires app restart
                self?.handleSyncSettingChanged()
            }
            .store(in: &cancellables)
    }

    private func setupCleanupTimer() {
        // Run cleanup every minute
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performCleanup()
            }
        }
    }

    private func handleSyncSettingChanged() {
        // In a real app, you'd prompt for restart or handle migration
    }

    // MARK: - CRUD Operations

    /// Add a new clipboard item
    func addItem(_ item: ClipboardItem) throws {
        // Check for duplicates based on settings
        if settings.duplicateDetection == .all {
            if let existing = try findByHash(item.contentHash) {
                // Update existing item's timestamp instead of adding duplicate
                existing.copiedAt = Date()
                try modelContext.save()
                return
            }
        }

        modelContext.insert(item)
        try modelContext.save()

        // Enforce history limit
        try enforceHistoryLimit()
        updateCounts()
    }

    /// Get all items sorted by recency, pinned first
    func getAllItems() throws -> [ClipboardItem] {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: ClipboardItem.defaultSortDescriptors
        )
        return try modelContext.fetch(descriptor)
    }

    /// Get pinned items only
    func getPinnedItems() throws -> [ClipboardItem] {
        let predicate = #Predicate<ClipboardItem> { item in
            item.isPinned
        }
        var descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)
        descriptor.sortBy = [
            SortDescriptor(\.pinOrder, order: .reverse)
        ]
        return try modelContext.fetch(descriptor)
    }

    /// Get recent items (non-pinned)
    func getRecentItems(limit: Int? = nil) throws -> [ClipboardItem] {
        let predicate = #Predicate<ClipboardItem> { item in
            !item.isPinned
        }
        var descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.copiedAt, order: .reverse)]
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        return try modelContext.fetch(descriptor)
    }

    /// Search items by text
    func search(query: String, mode: SearchMode = .fuzzy) throws -> [ClipboardItem] {
        let items = try getAllItems()

        switch mode {
        case .exact:
            return items.filter { item in
                item.searchableText.localizedCaseInsensitiveContains(query)
            }

        case .fuzzy:
            return items.filter { item in
                fuzzyMatch(text: item.searchableText, query: query)
            }.sorted { item1, item2 in
                // Sort by match quality
                let score1 = fuzzyScore(text: item1.searchableText, query: query)
                let score2 = fuzzyScore(text: item2.searchableText, query: query)
                return score1 > score2
            }

        case .regex:
            guard let regex = try? NSRegularExpression(pattern: query, options: .caseInsensitive) else {
                return []
            }
            return items.filter { item in
                let range = NSRange(item.searchableText.startIndex..., in: item.searchableText)
                return regex.firstMatch(in: item.searchableText, range: range) != nil
            }
        }
    }

    /// Find item by hash
    func findByHash(_ hash: String) throws -> ClipboardItem? {
        let predicate = #Predicate<ClipboardItem> { item in
            item.contentHash == hash
        }
        var descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Delete an item
    func deleteItem(_ item: ClipboardItem) throws {
        modelContext.delete(item)
        try modelContext.save()
        updateCounts()
    }

    /// Delete multiple items
    func deleteItems(_ items: [ClipboardItem]) throws {
        for item in items {
            modelContext.delete(item)
        }
        try modelContext.save()
        updateCounts()
    }

    /// Clear all history (optionally keep pinned)
    func clearHistory(keepPinned: Bool = true) throws {
        if keepPinned {
            let predicate = #Predicate<ClipboardItem> { item in
                !item.isPinned
            }
            try modelContext.delete(model: ClipboardItem.self, where: predicate)
        } else {
            try modelContext.delete(model: ClipboardItem.self)
        }
        try modelContext.save()
        updateCounts()
    }

    /// Toggle pin status
    func togglePin(_ item: ClipboardItem) throws {
        item.togglePin()
        try modelContext.save()
        updateCounts()
    }

    /// Mark item as pasted
    func markAsPasted(_ item: ClipboardItem) throws {
        item.markAsPasted()
        try modelContext.save()
    }

    // MARK: - Cleanup

    /// Enforce maximum history size
    private func enforceHistoryLimit() throws {
        // Get non-pinned items count
        let predicate = #Predicate<ClipboardItem> { item in
            !item.isPinned
        }
        var descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.copiedAt, order: .forward)]

        let nonPinnedItems = try modelContext.fetch(descriptor)
        let excess = nonPinnedItems.count - settings.maxHistorySize

        if excess > 0 {
            // Delete oldest items
            for i in 0..<excess {
                modelContext.delete(nonPinnedItems[i])
            }
            try modelContext.save()
        }
    }

    /// Perform periodic cleanup
    private func performCleanup() {
        do {
            // Delete old sensitive items
            if settings.autoDeleteSensitiveAfter > 0 {
                let cutoff = Date().addingTimeInterval(-settings.autoDeleteSensitiveAfter)
                let predicate = #Predicate<ClipboardItem> { item in
                    item.isSensitive && item.copiedAt < cutoff
                }
                try modelContext.delete(model: ClipboardItem.self, where: predicate)
                try modelContext.save()
            }

            // Enforce history limit
            try enforceHistoryLimit()
            updateCounts()
        } catch {
            print("Cleanup error: \(error)")
        }
    }

    // MARK: - Stats

    private func updateCounts() {
        do {
            let allDescriptor = FetchDescriptor<ClipboardItem>()
            itemCount = try modelContext.fetchCount(allDescriptor)

            let pinnedPredicate = #Predicate<ClipboardItem> { item in
                item.isPinned
            }
            let pinnedDescriptor = FetchDescriptor<ClipboardItem>(predicate: pinnedPredicate)
            pinnedCount = try modelContext.fetchCount(pinnedDescriptor)
        } catch {
            print("Count update error: \(error)")
        }
    }

    // MARK: - Fuzzy Search

    private func fuzzyMatch(text: String, query: String) -> Bool {
        let text = text.lowercased()
        let query = query.lowercased()

        var textIndex = text.startIndex
        var queryIndex = query.startIndex

        while textIndex < text.endIndex && queryIndex < query.endIndex {
            if text[textIndex] == query[queryIndex] {
                queryIndex = query.index(after: queryIndex)
            }
            textIndex = text.index(after: textIndex)
        }

        return queryIndex == query.endIndex
    }

    private func fuzzyScore(text: String, query: String) -> Int {
        let text = text.lowercased()
        let query = query.lowercased()

        var score = 0
        var consecutive = 0
        var textIndex = text.startIndex
        var queryIndex = query.startIndex
        var lastMatchIndex: String.Index?

        while textIndex < text.endIndex && queryIndex < query.endIndex {
            if text[textIndex] == query[queryIndex] {
                score += 1

                // Bonus for consecutive matches
                if let last = lastMatchIndex, text.index(after: last) == textIndex {
                    consecutive += 1
                    score += consecutive * 2
                } else {
                    consecutive = 0
                }

                // Bonus for match at start
                if textIndex == text.startIndex {
                    score += 10
                }

                // Bonus for match after separator
                if textIndex > text.startIndex {
                    let prevIndex = text.index(before: textIndex)
                    let prevChar = text[prevIndex]
                    if prevChar == " " || prevChar == "_" || prevChar == "-" || prevChar == "/" {
                        score += 5
                    }
                }

                lastMatchIndex = textIndex
                queryIndex = query.index(after: queryIndex)
            }
            textIndex = text.index(after: textIndex)
        }

        // Penalty for longer text
        score -= text.count / 10

        return score
    }

    // MARK: - Export/Import

    /// Export all items to JSON
    func exportToJSON() throws -> Data {
        let items = try getAllItems()
        let exportItems = items.map { item -> [String: Any] in
            var dict: [String: Any] = [
                "id": item.id.uuidString,
                "contentType": item.contentTypeRaw,
                "copiedAt": ISO8601DateFormatter().string(from: item.copiedAt),
                "isPinned": item.isPinned,
                "pasteCount": item.pasteCount
            ]

            if let text = item.text {
                dict["text"] = text
            }

            if let appName = item.sourceAppName {
                dict["sourceApp"] = appName
            }

            return dict
        }

        return try JSONSerialization.data(withJSONObject: exportItems, options: .prettyPrinted)
    }

    /// Get storage statistics
    func getStorageStats() throws -> StorageStats {
        let items = try getAllItems()

        var totalSize = 0
        var textCount = 0
        var imageCount = 0
        var fileCount = 0

        for item in items {
            totalSize += item.contentSize

            switch item.contentType {
            case .plainText, .rtf, .html:
                textCount += 1
            case .image, .png, .tiff, .jpeg:
                imageCount += 1
            case .fileURL:
                fileCount += 1
            default:
                break
            }
        }

        return StorageStats(
            totalItems: items.count,
            totalSize: totalSize,
            textItems: textCount,
            imageItems: imageCount,
            fileItems: fileCount,
            pinnedItems: pinnedCount
        )
    }
}

// MARK: - Storage Stats

struct StorageStats {
    let totalItems: Int
    let totalSize: Int
    let textItems: Int
    let imageItems: Int
    let fileItems: Int
    let pinnedItems: Int

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
}
