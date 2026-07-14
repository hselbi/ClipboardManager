import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    // MARK: - Properties

    private let appGroupIdentifier = "group.com.hselbi.clipboardmanager"
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)

        handleSharedContent()
    }

    // MARK: - Handle Shared Content

    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            showError("No content to share")
            return
        }

        let group = DispatchGroup()
        var sharedText: String?
        var sharedURL: URL?
        var sharedImage: UIImage?

        for attachment in attachments {
            // Handle plain text
            if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                group.enter()
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                    if let text = item as? String {
                        sharedText = text
                    }
                    group.leave()
                }
            }

            // Handle URL
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                    if let url = item as? URL {
                        sharedURL = url
                    }
                    group.leave()
                }
            }

            // Handle image
            if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                group.enter()
                attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                    if let imageURL = item as? URL, let data = try? Data(contentsOf: imageURL) {
                        sharedImage = UIImage(data: data)
                    } else if let image = item as? UIImage {
                        sharedImage = image
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.saveSharedContent(text: sharedText, url: sharedURL, image: sharedImage)
        }
    }

    // MARK: - Save Content

    private func saveSharedContent(text: String?, url: URL?, image: UIImage?) {
        var items = getSharedItems()

        // Create new item
        if let text = text {
            let item = SharedClipboardItem(
                id: UUID().uuidString,
                text: text,
                copiedAt: Date(),
                contentType: "text"
            )
            items.insert(item, at: 0)
        }

        if let url = url {
            let item = SharedClipboardItem(
                id: UUID().uuidString,
                text: url.absoluteString,
                copiedAt: Date(),
                contentType: "url"
            )
            items.insert(item, at: 0)
        }

        if let image = image {
            // Save image to shared container
            if let filename = saveImage(image) {
                let item = SharedClipboardItem(
                    id: UUID().uuidString,
                    text: "[Image]",
                    copiedAt: Date(),
                    contentType: "image",
                    imageFilename: filename
                )
                items.insert(item, at: 0)
            }
        }

        // Limit items
        if items.count > 100 {
            items = Array(items.prefix(100))
        }

        // Save items
        saveSharedItems(items)

        // Notify main app
        notifyMainApp()

        // Show success and close
        showSuccess()
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

    private func saveImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }

        let filename = UUID().uuidString + ".jpg"
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return nil }

        let fileURL = containerURL.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return filename
        } catch {
            return nil
        }
    }

    private func notifyMainApp() {
        let notificationName = CFNotificationName(
            "com.hselbi.clipboardmanager.newSharedContent" as CFString
        )
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notificationName,
            nil,
            nil,
            true
        )
    }

    // MARK: - UI Feedback

    private func showSuccess() {
        let alert = UIAlertController(
            title: "Saved",
            message: "Content saved to Clipboard Manager",
            preferredStyle: .alert
        )

        present(alert, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 0))
        })

        present(alert, animated: true)
    }
}

// MARK: - Shared Clipboard Item

struct SharedClipboardItem: Codable, Identifiable {
    let id: String
    let text: String
    let copiedAt: Date
    let contentType: String
    var imageFilename: String?

    var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 50 {
            return String(trimmed.prefix(50)) + "..."
        }
        return trimmed
    }
}
