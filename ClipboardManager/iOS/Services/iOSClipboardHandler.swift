import Foundation
import UIKit
import Combine
import SwiftData

// MARK: - iOS Clipboard Handler

/// Handles clipboard operations on iOS with privacy considerations
/// Note: iOS doesn't allow background clipboard monitoring
@MainActor
final class iOSClipboardHandler: ObservableObject {
    // MARK: - Properties

    @Published private(set) var lastCapturedItem: ClipboardItem?
    @Published private(set) var isPastePermissionGranted = false
    @Published private(set) var showingPastePermissionAlert = false

    private let pasteboard = UIPasteboard.general
    private let settings: AppSettings
    private var lastChangeCount: Int
    private var cancellables = Set<AnyCancellable>()

    // Callback for when new item is captured
    var onItemCaptured: ((ClipboardItem) -> Void)?

    // MARK: - Initialization

    init(settings: AppSettings) {
        self.settings = settings
        self.lastChangeCount = pasteboard.changeCount

        setupNotifications()
    }

    // MARK: - Setup

    private func setupNotifications() {
        // Check clipboard when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkClipboardOnForeground()
            }
            .store(in: &cancellables)

        // Also check when app will enter foreground
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.checkClipboardOnForeground()
            }
            .store(in: &cancellables)

        // Monitor pasteboard changes (only works when app is active)
        NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)
            .sink { [weak self] _ in
                self?.handlePasteboardChange()
            }
            .store(in: &cancellables)
    }

    // MARK: - Clipboard Access

    /// Check clipboard when app comes to foreground
    /// iOS 14+ shows paste notification to user
    private func checkClipboardOnForeground() {
        let currentChangeCount = pasteboard.changeCount

        // Only process if clipboard has changed
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // On iOS 16+, we need to handle UIPasteControl or check permission
        if #available(iOS 16.0, *) {
            // Don't auto-read, wait for user to explicitly paste
            // Show UI hint that new content is available
            showingPastePermissionAlert = hasContent()
        } else {
            // On older iOS, reading clipboard shows a banner notification
            // We can still read but user will see the notification
            captureCurrentClipboard()
        }
    }

    /// Handle pasteboard change notification
    private func handlePasteboardChange() {
        lastChangeCount = pasteboard.changeCount
    }

    /// Check if pasteboard has content
    func hasContent() -> Bool {
        return pasteboard.hasStrings ||
               pasteboard.hasImages ||
               pasteboard.hasURLs
    }

    /// Capture current clipboard content (call after user grants permission)
    func captureCurrentClipboard() {
        guard let item = extractClipboardContent() else { return }

        // Check for duplicates
        if let lastItem = lastCapturedItem,
           lastItem.contentHash == item.contentHash {
            return
        }

        // Check ignored patterns
        if let text = item.text, settings.shouldIgnoreContent(text) {
            return
        }

        // Check size limits
        if settings.ignoreLargeItems && item.contentSize > settings.largeItemThreshold {
            return
        }

        // Check for sensitive content
        if let text = item.text, settings.isSensitiveContent(text) {
            item.isSensitive = true
        }

        lastCapturedItem = item
        onItemCaptured?(item)
        isPastePermissionGranted = true
        showingPastePermissionAlert = false
    }

    // MARK: - Content Extraction

    private func extractClipboardContent() -> ClipboardItem? {
        var text: String?
        var imageData: Data?
        var fileURL: URL?
        var contentType: ClipboardContentType = .unknown
        var availableTypes: [ClipboardContentType] = []

        // Check for text
        if pasteboard.hasStrings, let string = pasteboard.string {
            let processedText = settings.trimWhitespace
                ? string.trimmingCharacters(in: .whitespacesAndNewlines)
                : string

            if !processedText.isEmpty {
                text = processedText
                contentType = .plainText
                availableTypes.append(.plainText)
            }
        }

        // Check for URLs
        if pasteboard.hasURLs, let url = pasteboard.url {
            fileURL = url
            text = text ?? url.absoluteString
            if url.isFileURL {
                contentType = contentType == .unknown ? .fileURL : contentType
                availableTypes.append(.fileURL)
            } else {
                contentType = contentType == .unknown ? .url : contentType
                availableTypes.append(.url)
            }
        }

        // Check for images
        if pasteboard.hasImages, let image = pasteboard.image {
            // Compress and convert to PNG data
            if let data = processImage(image) {
                imageData = data
                contentType = contentType == .unknown ? .png : contentType
                availableTypes.append(.png)
            }
        }

        // Must have some content
        guard text != nil || imageData != nil || fileURL != nil else {
            return nil
        }

        return ClipboardItem(
            text: text,
            imageData: imageData,
            fileURL: fileURL,
            contentType: contentType,
            availableTypes: availableTypes,
            sourceAppBundleID: nil, // Can't determine on iOS
            sourceAppName: nil
        )
    }

    // MARK: - Image Processing

    private func processImage(_ image: UIImage) -> Data? {
        // Calculate target size based on settings
        let maxDimension: CGFloat = 2048

        var processedImage = image

        // Resize if too large
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                processedImage = resized
            }
            UIGraphicsEndImageContext()
        }

        // Convert to PNG
        guard let pngData = processedImage.pngData() else {
            return nil
        }

        // Check size limit
        if pngData.count > settings.imageMaxSize {
            // Try JPEG compression
            return processedImage.jpegData(compressionQuality: 0.7)
        }

        return pngData
    }

    // MARK: - Write to Clipboard

    /// Write item to clipboard
    func writeToClipboard(_ item: ClipboardItem, removeFormatting: Bool = false) {
        pasteboard.items = []

        var items: [[String: Any]] = []
        var itemDict: [String: Any] = [:]

        // Add text
        if let text = item.text {
            itemDict[UIPasteboard.typeListString[0] as String] = text
        }

        // Add image
        if let imageData = item.imageData {
            itemDict[UIPasteboard.typeListImage[0] as String] = UIImage(data: imageData) as Any
        }

        // Add URL
        if let url = item.fileURL {
            itemDict[UIPasteboard.typeListURL[0] as String] = url
        }

        if !itemDict.isEmpty {
            items.append(itemDict)
            pasteboard.items = items
        }

        lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Clear Clipboard

    /// Clear the clipboard
    func clearClipboard() {
        pasteboard.items = []
        lastChangeCount = pasteboard.changeCount
    }
}

// MARK: - iOS Keyboard Extension Handler

/// Handler for keyboard extension clipboard integration
final class KeyboardClipboardHandler {
    // MARK: - Properties

    private let settings: AppSettings

    // User defaults shared with main app via App Groups
    private let sharedDefaults: UserDefaults?

    // MARK: - Initialization

    init(settings: AppSettings, appGroupIdentifier: String) {
        self.settings = settings
        self.sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
    }

    // MARK: - Shared Data

    /// Get recent items from shared storage
    func getRecentItems() -> [SharedClipboardItem] {
        guard let data = sharedDefaults?.data(forKey: "recentClipboardItems"),
              let items = try? JSONDecoder().decode([SharedClipboardItem].self, from: data) else {
            return []
        }
        return items
    }

    /// Save recent items to shared storage
    func saveRecentItems(_ items: [SharedClipboardItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        sharedDefaults?.set(data, forKey: "recentClipboardItems")
    }

    /// Add item from keyboard
    func addItem(text: String) {
        var items = getRecentItems()

        let newItem = SharedClipboardItem(
            id: UUID().uuidString,
            text: text,
            copiedAt: Date()
        )

        // Remove duplicates
        items.removeAll { $0.text == text }

        // Add to front
        items.insert(newItem, at: 0)

        // Limit size
        if items.count > 50 {
            items = Array(items.prefix(50))
        }

        saveRecentItems(items)
    }
}

// MARK: - Shared Clipboard Item

/// Lightweight item for sharing between app and extensions
struct SharedClipboardItem: Codable, Identifiable {
    let id: String
    let text: String
    let copiedAt: Date

    var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 50 {
            return String(trimmed.prefix(50)) + "..."
        }
        return trimmed
    }
}

// MARK: - Share Extension Handler

/// Handler for Share Extension clipboard integration
final class ShareExtensionHandler {
    // MARK: - Properties

    private let appGroupIdentifier: String
    private let sharedDefaults: UserDefaults?

    // MARK: - Initialization

    init(appGroupIdentifier: String) {
        self.appGroupIdentifier = appGroupIdentifier
        self.sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
    }

    // MARK: - Handle Shared Content

    /// Save shared text content
    func saveSharedText(_ text: String) {
        var items = getSharedItems()

        let newItem = SharedClipboardItem(
            id: UUID().uuidString,
            text: text,
            copiedAt: Date()
        )

        items.insert(newItem, at: 0)

        // Limit size
        if items.count > 100 {
            items = Array(items.prefix(100))
        }

        saveSharedItems(items)

        // Notify main app
        notifyMainApp()
    }

    /// Save shared URL
    func saveSharedURL(_ url: URL) {
        saveSharedText(url.absoluteString)
    }

    /// Save shared image (as reference)
    func saveSharedImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }

        let filename = UUID().uuidString + ".jpg"
        let fileURL = getSharedContainerURL()?.appendingPathComponent(filename)

        guard let url = fileURL else { return nil }

        do {
            try data.write(to: url)
            return filename
        } catch {
            return nil
        }
    }

    // MARK: - Storage

    private func getSharedItems() -> [SharedClipboardItem] {
        guard let data = sharedDefaults?.data(forKey: "sharedClipboardItems"),
              let items = try? JSONDecoder().decode([SharedClipboardItem].self, from: data) else {
            return []
        }
        return items
    }

    private func saveSharedItems(_ items: [SharedClipboardItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        sharedDefaults?.set(data, forKey: "sharedClipboardItems")
    }

    private func getSharedContainerURL() -> URL? {
        return FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }

    private func notifyMainApp() {
        // Use Darwin notifications to notify main app
        let notificationName = CFNotificationName(
            "com.clipboard.manager.newSharedContent" as CFString
        )
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notificationName,
            nil,
            nil,
            true
        )
    }
}

// MARK: - Shortcuts Integration

import AppIntents

/// App Intent for saving clipboard via Shortcuts
@available(iOS 16.0, macOS 13.0, *)
struct SaveClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Save Clipboard"
    static var description = IntentDescription("Save current clipboard content to history")

    func perform() async throws -> some IntentResult {
        // This would integrate with the main app's data store
        return .result()
    }
}

/// App Intent for pasting from history via Shortcuts
@available(iOS 16.0, macOS 13.0, *)
struct PasteFromHistoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Paste from History"
    static var description = IntentDescription("Select and paste an item from clipboard history")

    @Parameter(title: "Search Query")
    var query: String?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // This would search history and return the selected item
        return .result(value: "")
    }
}

/// App Intent for clearing history
@available(iOS 16.0, macOS 13.0, *)
struct ClearHistoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Clear Clipboard History"
    static var description = IntentDescription("Clear all clipboard history")

    @Parameter(title: "Keep Pinned Items", default: true)
    var keepPinned: Bool

    func perform() async throws -> some IntentResult {
        // This would clear history through the data store
        return .result()
    }
}
