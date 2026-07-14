import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct ClipboardEntry: TimelineEntry {
    let date: Date
    let items: [WidgetClipboardItem]
    let configuration: ConfigurationAppIntent
}

// MARK: - Widget Item

struct WidgetClipboardItem: Identifiable {
    let id: String
    let text: String
    let contentType: String
    let copiedAt: Date

    var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 40 {
            return String(trimmed.prefix(40)) + "..."
        }
        return trimmed
    }

    var iconName: String {
        switch contentType {
        case "image": return "photo"
        case "url": return "link"
        case "file": return "folder"
        default: return "text.alignleft"
        }
    }
}

// MARK: - Configuration Intent

import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("Configure the clipboard widget")

    @Parameter(title: "Show Pinned Only", default: false)
    var showPinnedOnly: Bool

    @Parameter(title: "Item Count", default: 5)
    var itemCount: Int
}

// MARK: - Timeline Provider

struct ClipboardTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = ClipboardEntry
    typealias Intent = ConfigurationAppIntent

    private let appGroupIdentifier = "group.com.hselbi.clipboardmanager"

    func placeholder(in context: Context) -> ClipboardEntry {
        ClipboardEntry(
            date: Date(),
            items: [
                WidgetClipboardItem(id: "1", text: "Sample clipboard item", contentType: "text", copiedAt: Date())
            ],
            configuration: ConfigurationAppIntent()
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> ClipboardEntry {
        let items = loadItems(count: configuration.itemCount)
        return ClipboardEntry(date: Date(), items: items, configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<ClipboardEntry> {
        let items = loadItems(count: configuration.itemCount)
        let entry = ClipboardEntry(date: Date(), items: items, configuration: configuration)

        // Update every 5 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func loadItems(count: Int) -> [WidgetClipboardItem] {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: "sharedClipboardItems"),
              let items = try? JSONDecoder().decode([SharedItem].self, from: data) else {
            return []
        }

        return items.prefix(count).map { item in
            WidgetClipboardItem(
                id: item.id,
                text: item.text,
                contentType: item.contentType,
                copiedAt: item.copiedAt
            )
        }
    }
}

// Shared item structure matching the main app
private struct SharedItem: Codable {
    let id: String
    let text: String
    let copiedAt: Date
    let contentType: String
}

// MARK: - Widget Views

struct ClipboardWidgetEntryView: View {
    var entry: ClipboardEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryInline:
            accessoryInline
        default:
            mediumWidget
        }
    }

    // MARK: - Small Widget

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.on.clipboard.fill")
                    .foregroundColor(.accentColor)
                Text("Clipboard")
                    .font(.caption.bold())
            }

            if let item = entry.items.first {
                Text(item.displayText)
                    .font(.caption)
                    .lineLimit(3)
                    .foregroundColor(.primary)
            } else {
                Text("No items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(entry.items.count) items")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Medium Widget

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.on.clipboard.fill")
                    .foregroundColor(.accentColor)
                Text("Clipboard History")
                    .font(.headline)
                Spacer()
            }

            if entry.items.isEmpty {
                Text("No clipboard items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(entry.items.prefix(3)) { item in
                    HStack {
                        Image(systemName: item.iconName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 16)

                        Text(item.displayText)
                            .font(.caption)
                            .lineLimit(1)

                        Spacer()

                        Text(item.copiedAt.formatted(.relative(presentation: .abbreviated)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Large Widget

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.on.clipboard.fill")
                    .foregroundColor(.accentColor)
                Text("Clipboard History")
                    .font(.headline)
                Spacer()
                Text("\(entry.items.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            if entry.items.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "doc.on.clipboard")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No clipboard items")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.items) { item in
                    Link(destination: URL(string: "clipboardmanager://paste/\(item.id)")!) {
                        HStack(spacing: 12) {
                            Image(systemName: item.iconName)
                                .font(.body)
                                .foregroundColor(.accentColor)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.displayText)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                    .foregroundColor(.primary)

                                Text(item.copiedAt.formatted(.relative(presentation: .abbreviated)))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    if item.id != entry.items.last?.id {
                        Divider()
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
    }

    // MARK: - Lock Screen Widgets

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "doc.on.clipboard")
                .font(.title2)
        }
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                Text("Clipboard")
                    .font(.headline)
            }

            if let item = entry.items.first {
                Text(item.displayText)
                    .font(.caption)
                    .lineLimit(2)
            }
        }
    }

    private var accessoryInline: some View {
        HStack {
            Image(systemName: "doc.on.clipboard")
            if let item = entry.items.first {
                Text(item.displayText)
            } else {
                Text("No items")
            }
        }
    }
}

// MARK: - Widget Configuration

struct ClipboardWidget: Widget {
    let kind: String = "ClipboardWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: ClipboardTimelineProvider()
        ) { entry in
            ClipboardWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Clipboard History")
        .description("Quick access to your clipboard history")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Widget Bundle

@main
struct ClipboardWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClipboardWidget()
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    ClipboardWidget()
} timeline: {
    ClipboardEntry(
        date: .now,
        items: [
            WidgetClipboardItem(id: "1", text: "Hello world", contentType: "text", copiedAt: Date()),
            WidgetClipboardItem(id: "2", text: "https://example.com", contentType: "url", copiedAt: Date().addingTimeInterval(-60)),
            WidgetClipboardItem(id: "3", text: "Some longer text that will be truncated", contentType: "text", copiedAt: Date().addingTimeInterval(-120))
        ],
        configuration: ConfigurationAppIntent()
    )
}
