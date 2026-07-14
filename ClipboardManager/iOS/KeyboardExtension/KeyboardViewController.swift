import UIKit
import SwiftUI

// MARK: - Keyboard View Controller

class KeyboardViewController: UIInputViewController {
    // MARK: - Properties

    private var hostingController: UIHostingController<KeyboardView>?
    private let clipboardHandler: KeyboardClipboardHandler
    private let appGroupIdentifier = "group.com.hselbi.clipboardmanager"

    // MARK: - Initialization

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.clipboardHandler = KeyboardClipboardHandler(
            settings: AppSettings(),
            appGroupIdentifier: appGroupIdentifier
        )
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        self.clipboardHandler = KeyboardClipboardHandler(
            settings: AppSettings(),
            appGroupIdentifier: appGroupIdentifier
        )
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardView()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        hostingController?.view.frame = view.bounds
    }

    // MARK: - Setup

    private func setupKeyboardView() {
        let keyboardView = KeyboardView(
            clipboardHandler: clipboardHandler,
            onItemSelected: { [weak self] text in
                self?.textDocumentProxy.insertText(text)
            },
            onNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            },
            onBackspace: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            },
            hasFullAccess: hasFullAccess
        )

        let hostingController = UIHostingController(rootView: keyboardView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        self.hostingController = hostingController
    }
}

// MARK: - Keyboard View

struct KeyboardView: View {
    let clipboardHandler: KeyboardClipboardHandler
    let onItemSelected: (String) -> Void
    let onNextKeyboard: () -> Void
    let onBackspace: () -> Void
    let hasFullAccess: Bool

    @State private var items: [SharedClipboardItem] = []

    var body: some View {
        VStack(spacing: 0) {
            // Clipboard items row
            if hasFullAccess {
                clipboardItemsRow
            } else {
                noAccessView
            }

            Divider()

            // Bottom toolbar
            bottomToolbar
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            loadItems()
        }
    }

    // MARK: - Clipboard Items Row

    private var clipboardItemsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(items) { item in
                    ClipboardChip(item: item) {
                        onItemSelected(item.text)
                    }
                }

                if items.isEmpty {
                    Text("No clipboard items")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(height: 50)
    }

    // MARK: - No Access View

    private var noAccessView: some View {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundColor(.secondary)

            Text("Enable Full Access in Settings")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 50)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            // Next keyboard button
            Button(action: onNextKeyboard) {
                Image(systemName: "globe")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Paste from clipboard
            Button(action: pasteFromClipboard) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Paste")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()

            // Backspace button
            Button(action: onBackspace) {
                Image(systemName: "delete.left")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
    }

    // MARK: - Actions

    private func loadItems() {
        items = clipboardHandler.getRecentItems()
    }

    private func pasteFromClipboard() {
        if let string = UIPasteboard.general.string {
            onItemSelected(string)
            clipboardHandler.addItem(text: string)
            loadItems()
        }
    }
}

// MARK: - Clipboard Chip

struct ClipboardChip: View {
    let item: SharedClipboardItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(item.displayText)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared Clipboard Item (for keyboard)

struct SharedClipboardItem: Codable, Identifiable {
    let id: String
    let text: String
    let copiedAt: Date

    var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 30 {
            return String(trimmed.prefix(30)) + "..."
        }
        return trimmed
    }
}

// MARK: - Keyboard Clipboard Handler

final class KeyboardClipboardHandler {
    private let settings: AppSettings
    private let sharedDefaults: UserDefaults?

    init(settings: AppSettings, appGroupIdentifier: String) {
        self.settings = settings
        self.sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
    }

    func getRecentItems() -> [SharedClipboardItem] {
        guard let data = sharedDefaults?.data(forKey: "sharedClipboardItems"),
              let items = try? JSONDecoder().decode([SharedClipboardItem].self, from: data) else {
            return []
        }
        return Array(items.prefix(20))
    }

    func addItem(text: String) {
        var items = getRecentItems()

        let newItem = SharedClipboardItem(
            id: UUID().uuidString,
            text: text,
            copiedAt: Date()
        )

        items.removeAll { $0.text == text }
        items.insert(newItem, at: 0)

        if items.count > 50 {
            items = Array(items.prefix(50))
        }

        guard let data = try? JSONEncoder().encode(items) else { return }
        sharedDefaults?.set(data, forKey: "sharedClipboardItems")
    }
}

// MARK: - Minimal AppSettings for Keyboard

class AppSettings: ObservableObject {
    // Minimal settings needed for keyboard extension
    init() {}
}
