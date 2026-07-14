import SwiftUI
import SwiftData

// MARK: - iOS App Entry Point

@main
struct ClipboardManageriOSApp: App {
    // MARK: - Properties

    @StateObject private var settings = AppSettings()
    @StateObject private var clipboardHandler: iOSClipboardHandler

    private let modelContainer: ModelContainer

    // MARK: - Initialization

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _clipboardHandler = StateObject(wrappedValue: iOSClipboardHandler(settings: settings))

        // Setup model container
        do {
            let schema = Schema([ClipboardItem.self])
            let configuration: ModelConfiguration

            if settings.enableiCloudSync {
                configuration = ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .automatic
                )
            } else {
                configuration = ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .none
                )
            }

            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to initialize model container: \(error)")
        }
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView(clipboardHandler: clipboardHandler, settings: settings)
                .modelContainer(modelContainer)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    handleEnterBackground()
                }
        }
    }

    // MARK: - Background Handling

    private func handleEnterBackground() {
        if settings.clearHistoryOnQuit {
            // Clear non-pinned items
            // This would be done through the model context
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @ObservedObject var clipboardHandler: iOSClipboardHandler
    @ObservedObject var settings: AppSettings

    @Environment(\.modelContext) private var modelContext

    init(clipboardHandler: iOSClipboardHandler, settings: AppSettings) {
        self.clipboardHandler = clipboardHandler
        self.settings = settings

        // Setup item capture callback
        clipboardHandler.onItemCaptured = { [weak modelContext] item in
            modelContext?.insert(item)
        }
    }

    var body: some View {
        ClipboardListView(clipboardHandler: clipboardHandler, settings: settings)
    }
}

// MARK: - iPad Sidebar View

struct iPadSidebarView: View {
    @ObservedObject var clipboardHandler: iOSClipboardHandler
    @ObservedObject var settings: AppSettings

    @State private var selectedSection: SidebarSection? = .all

    enum SidebarSection: String, CaseIterable, Identifiable {
        case all = "All"
        case pinned = "Pinned"
        case text = "Text"
        case images = "Images"
        case links = "Links"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .all: return "clock"
            case .pinned: return "pin"
            case .text: return "text.alignleft"
            case .images: return "photo"
            case .links: return "link"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("Clipboard")
        } detail: {
            if let section = selectedSection {
                switch section {
                case .settings:
                    iOSSettingsView(settings: settings)
                default:
                    FilteredClipboardView(
                        section: section,
                        clipboardHandler: clipboardHandler,
                        settings: settings
                    )
                }
            } else {
                Text("Select a category")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Filtered Clipboard View

struct FilteredClipboardView: View {
    let section: iPadSidebarView.SidebarSection
    @ObservedObject var clipboardHandler: iOSClipboardHandler
    @ObservedObject var settings: AppSettings

    @Query private var allItems: [ClipboardItem]

    var filteredItems: [ClipboardItem] {
        switch section {
        case .all:
            return allItems
        case .pinned:
            return allItems.filter { $0.isPinned }
        case .text:
            return allItems.filter { $0.contentType == .plainText || $0.contentType == .rtf || $0.contentType == .html }
        case .images:
            return allItems.filter { $0.contentType == .image || $0.contentType == .png || $0.contentType == .tiff || $0.contentType == .jpeg }
        case .links:
            return allItems.filter { $0.contentType == .url || $0.contentType == .fileURL }
        case .settings:
            return []
        }
    }

    var body: some View {
        List(filteredItems) { item in
            ClipboardItemCell(
                item: item,
                settings: settings,
                onTap: { },
                onCopy: { clipboardHandler.writeToClipboard(item) }
            )
        }
        .navigationTitle(section.rawValue)
        .overlay {
            if filteredItems.isEmpty {
                ContentUnavailableView {
                    Label("No Items", systemImage: "tray")
                } description: {
                    Text("No clipboard items in this category")
                }
            }
        }
    }
}

// MARK: - Widget Support

import WidgetKit

struct ClipboardWidgetEntry: TimelineEntry {
    let date: Date
    let items: [SharedClipboardItem]
}

struct ClipboardWidgetProvider: TimelineProvider {
    typealias Entry = ClipboardWidgetEntry

    func placeholder(in context: Context) -> ClipboardWidgetEntry {
        ClipboardWidgetEntry(date: Date(), items: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (ClipboardWidgetEntry) -> Void) {
        let entry = ClipboardWidgetEntry(date: Date(), items: [])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClipboardWidgetEntry>) -> Void) {
        let entry = ClipboardWidgetEntry(date: Date(), items: getRecentItems())
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
        completion(timeline)
    }

    private func getRecentItems() -> [SharedClipboardItem] {
        guard let defaults = UserDefaults(suiteName: "group.com.clipboard.manager"),
              let data = defaults.data(forKey: "recentClipboardItems"),
              let items = try? JSONDecoder().decode([SharedClipboardItem].self, from: data) else {
            return []
        }
        return Array(items.prefix(5))
    }
}

// MARK: - Accessibility

extension ClipboardItem {
    var accessibilityLabel: String {
        var label = contentType.displayName

        if let text = text {
            label += ": " + String(text.prefix(100))
        }

        if isPinned {
            label += ", pinned"
        }

        return label
    }

    var accessibilityHint: String {
        "Double tap to copy to clipboard"
    }
}
