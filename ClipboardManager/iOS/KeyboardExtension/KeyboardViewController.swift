import UIKit
import SwiftUI

// MARK: - Keyboard View Controller

class KeyboardViewController: UIInputViewController {
    // MARK: - Properties

    private var hostingController: UIHostingController<KeyboardView>?
    private let clipboardHandler: KeyboardClipboardHandler
    private let appGroupIdentifier = "group.com.clipboard.manager"

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

        // Update hosting controller frame
        hostingController?.view.frame = view.bounds
    }

    // MARK: - Setup

    private func setupKeyboardView() {
        let keyboardView = KeyboardView(
            clipboardHandler: clipboardHandler,
            onItemSelected: { [weak self] text in
                self?.insertText(text)
            },
            onNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            },
            onBackspace: { [weak self] in
                self?.deleteBackward()
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

    // MARK: - Input

    private func insertText(_ text: String) {
        textDocumentProxy.insertText(text)
    }

    private func deleteBackward() {
        textDocumentProxy.deleteBackward()
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
    @State private var showingFullKeyboard = false

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

            // Save to history
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

// MARK: - Full Keyboard View

struct FullKeyboardView: View {
    let clipboardHandler: KeyboardClipboardHandler
    let onItemSelected: (String) -> Void
    let onDismiss: () -> Void

    @State private var items: [SharedClipboardItem] = []
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredItems) { item in
                    Button(action: { onItemSelected(item.text) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.text)
                                .lineLimit(2)
                                .font(.body)

                            Text(item.copiedAt.formatted(.relative(presentation: .abbreviated)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Clipboard History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .onAppear {
            items = clipboardHandler.getRecentItems()
        }
    }

    private var filteredItems: [SharedClipboardItem] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }
}
