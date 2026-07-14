import Foundation
import SwiftData
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
import IOKit
#else
import UIKit
#endif

// MARK: - Clipboard Content Types

/// Represents different types of clipboard content
enum ClipboardContentType: String, Codable, CaseIterable, Sendable {
    case plainText = "public.utf8-plain-text"
    case rtf = "public.rtf"
    case html = "public.html"
    case image = "public.image"
    case png = "public.png"
    case tiff = "public.tiff"
    case jpeg = "public.jpeg"
    case pdf = "com.adobe.pdf"
    case fileURL = "public.file-url"
    case url = "public.url"
    case color = "com.apple.cocoa.pasteboard.color"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .plainText: return "Text"
        case .rtf: return "Rich Text"
        case .html: return "HTML"
        case .image, .png, .tiff, .jpeg: return "Image"
        case .pdf: return "PDF"
        case .fileURL: return "File"
        case .url: return "URL"
        case .color: return "Color"
        case .unknown: return "Unknown"
        }
    }

    var utType: UTType? {
        switch self {
        case .plainText: return .plainText
        case .rtf: return .rtf
        case .html: return .html
        case .image: return .image
        case .png: return .png
        case .tiff: return .tiff
        case .jpeg: return .jpeg
        case .pdf: return .pdf
        case .fileURL: return .fileURL
        case .url: return .url
        case .color: return nil
        case .unknown: return nil
        }
    }

    var systemImageName: String {
        switch self {
        case .plainText: return "text.alignleft"
        case .rtf, .html: return "text.badge.star"
        case .image, .png, .tiff, .jpeg: return "photo"
        case .pdf: return "doc.richtext"
        case .fileURL: return "folder"
        case .url: return "link"
        case .color: return "paintpalette"
        case .unknown: return "questionmark.square"
        }
    }
}

// MARK: - Clipboard Item Model

/// Main model for clipboard history items
@Model
final class ClipboardItem {
    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Primary text content (for display and search)
    var text: String?

    /// Raw data storage for non-text content
    @Attribute(.externalStorage) var imageData: Data?

    /// File URL if content is a file reference
    var fileURLString: String?

    /// The primary content type
    var contentTypeRaw: String

    /// All available content types (for rich paste options)
    var availableTypesRaw: [String]

    /// When this item was copied
    var copiedAt: Date

    /// Last time this item was pasted
    var lastPastedAt: Date?

    /// Number of times this item was pasted
    var pasteCount: Int

    /// Whether this item is pinned (persistent)
    var isPinned: Bool

    /// Pin order (for sorting pinned items)
    var pinOrder: Int?

    /// Source application bundle identifier
    var sourceAppBundleID: String?

    /// Source application name
    var sourceAppName: String?

    /// Hash for deduplication
    var contentHash: String

    /// Whether this item contains sensitive data
    var isSensitive: Bool

    /// Device that created this item (for sync)
    var sourceDeviceID: String?

    /// RTF data if available
    @Attribute(.externalStorage) var rtfData: Data?

    /// HTML content if available
    var htmlContent: String?

    // MARK: - Computed Properties

    var contentType: ClipboardContentType {
        get { ClipboardContentType(rawValue: contentTypeRaw) ?? .unknown }
        set { contentTypeRaw = newValue.rawValue }
    }

    var availableTypes: [ClipboardContentType] {
        get { availableTypesRaw.compactMap { ClipboardContentType(rawValue: $0) } }
        set { availableTypesRaw = newValue.map { $0.rawValue } }
    }

    var fileURL: URL? {
        get { fileURLString.flatMap { URL(string: $0) } }
        set { fileURLString = newValue?.absoluteString }
    }

    /// Display text for UI (truncated if needed)
    var displayText: String {
        if let text = text {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 100 {
                return String(trimmed.prefix(100)) + "..."
            }
            return trimmed
        }

        if fileURL != nil {
            return fileURL?.lastPathComponent ?? "File"
        }

        if imageData != nil {
            return "[Image]"
        }

        return "[Unknown Content]"
    }

    /// Full text without truncation
    var fullText: String {
        text ?? fileURL?.absoluteString ?? "[No text content]"
    }

    /// Preview text for search
    var searchableText: String {
        var components: [String] = []

        if let text = text {
            components.append(text)
        }

        if let appName = sourceAppName {
            components.append(appName)
        }

        if let fileURL = fileURL {
            components.append(fileURL.lastPathComponent)
        }

        return components.joined(separator: " ")
    }

    /// Size of the content in bytes
    var contentSize: Int {
        var size = text?.utf8.count ?? 0
        size += imageData?.count ?? 0
        size += rtfData?.count ?? 0
        size += htmlContent?.utf8.count ?? 0
        return size
    }

    /// Formatted size string
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(contentSize), countStyle: .file)
    }

    // MARK: - Initialization

    init(
        text: String? = nil,
        imageData: Data? = nil,
        fileURL: URL? = nil,
        contentType: ClipboardContentType,
        availableTypes: [ClipboardContentType] = [],
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        isSensitive: Bool = false,
        rtfData: Data? = nil,
        htmlContent: String? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.imageData = imageData
        self.fileURLString = fileURL?.absoluteString
        self.contentTypeRaw = contentType.rawValue
        self.availableTypesRaw = availableTypes.map { $0.rawValue }
        self.copiedAt = Date()
        self.lastPastedAt = nil
        self.pasteCount = 0
        self.isPinned = false
        self.pinOrder = nil
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.isSensitive = isSensitive
        self.sourceDeviceID = DeviceIdentifier.current
        self.rtfData = rtfData
        self.htmlContent = htmlContent

        // Generate content hash for deduplication
        self.contentHash = Self.generateHash(
            text: text,
            imageData: imageData,
            fileURL: fileURL
        )
    }

    // MARK: - Hash Generation

    static func generateHash(text: String?, imageData: Data?, fileURL: URL?) -> String {
        var hasher = Hasher()

        if let text = text {
            hasher.combine(text)
        }

        if let imageData = imageData {
            // Hash only first and last 1KB for performance on large images
            let prefix = imageData.prefix(1024)
            let suffix = imageData.suffix(1024)
            hasher.combine(prefix)
            hasher.combine(suffix)
            hasher.combine(imageData.count)
        }

        if let fileURL = fileURL {
            hasher.combine(fileURL.absoluteString)
        }

        return String(hasher.finalize())
    }

    // MARK: - Actions

    func markAsPasted() {
        lastPastedAt = Date()
        pasteCount += 1
    }

    func togglePin() {
        isPinned.toggle()
        if isPinned {
            pinOrder = Int(Date().timeIntervalSince1970)
        } else {
            pinOrder = nil
        }
    }
}

// MARK: - Device Identifier

struct DeviceIdentifier {
    static var current: String {
        #if os(macOS)
        return getMacDeviceID()
        #else
        return getIOSDeviceID()
        #endif
    }

    #if os(macOS)
    private static func getMacDeviceID() -> String {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )

        guard platformExpert != 0 else {
            return "mac-unknown"
        }

        defer { IOObjectRelease(platformExpert) }

        if let serialNumberAsCFString = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        ) {
            if let serialNumber = serialNumberAsCFString.takeUnretainedValue() as? String {
                return "mac-\(serialNumber)"
            }
        }

        return "mac-unknown"
    }
    #endif

    #if os(iOS)
    private static func getIOSDeviceID() -> String {
        if let identifier = UIDevice.current.identifierForVendor?.uuidString {
            return "ios-\(identifier)"
        }
        return "ios-unknown"
    }
    #endif
}

// MARK: - Sorting and Filtering

extension ClipboardItem {
    /// Sort descriptor for most recent first, pinned items at top
    static var defaultSortDescriptors: [SortDescriptor<ClipboardItem>] {
        [
            SortDescriptor(\.isPinned, order: .reverse),
            SortDescriptor(\.pinOrder, order: .reverse),
            SortDescriptor(\.copiedAt, order: .reverse)
        ]
    }

    /// Predicate for non-sensitive items
    static var nonSensitivePredicate: Predicate<ClipboardItem> {
        #Predicate<ClipboardItem> { item in
            !item.isSensitive
        }
    }
}

// MARK: - Identifiable

extension ClipboardItem: Identifiable { }
