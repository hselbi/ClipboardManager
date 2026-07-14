import Foundation
import SwiftUI

// MARK: - App Settings

/// Observable settings object for the clipboard manager
@Observable
final class AppSettings {
    // MARK: - Storage Keys

    private enum Keys {
        static let maxHistorySize = "maxHistorySize"
        static let clipboardCheckInterval = "clipboardCheckInterval"
        static let enableSound = "enableSound"
        static let enableiCloudSync = "enableiCloudSync"
        static let ignoredApps = "ignoredApps"
        static let ignoredPatterns = "ignoredPatterns"
        static let showInMenuBar = "showInMenuBar"
        static let showInDock = "showInDock"
        static let launchAtLogin = "launchAtLogin"
        static let pasteAutomatically = "pasteAutomatically"
        static let removeFormattingByDefault = "removeFormattingByDefault"
        static let searchMode = "searchMode"
        static let showPreview = "showPreview"
        static let previewMaxLength = "previewMaxLength"
        static let enablePasswordManagerDetection = "enablePasswordManagerDetection"
        static let clearHistoryOnQuit = "clearHistoryOnQuit"
        static let globalHotkey = "globalHotkey"
        static let imageMaxSize = "imageMaxSize"
        static let ignoreLargeItems = "ignoreLargeItems"
        static let largeItemThreshold = "largeItemThreshold"
        static let duplicateDetection = "duplicateDetection"
        static let trimWhitespace = "trimWhitespace"
        static let ignoreConsecutiveDuplicates = "ignoreConsecutiveDuplicates"
        static let showSourceApp = "showSourceApp"
        static let enableEncryption = "enableEncryption"
        static let sensitiveContentPatterns = "sensitiveContentPatterns"
        static let autoDeleteSensitiveAfter = "autoDeleteSensitiveAfter"
    }

    // MARK: - Storage

    private let defaults: UserDefaults

    // MARK: - General Settings

    /// Maximum number of items to store in history (1-999)
    var maxHistorySize: Int {
        didSet {
            defaults.set(maxHistorySize, forKey: Keys.maxHistorySize)
        }
    }

    /// Interval for checking clipboard changes (in seconds)
    var clipboardCheckInterval: Double {
        didSet {
            defaults.set(clipboardCheckInterval, forKey: Keys.clipboardCheckInterval)
            NotificationCenter.default.post(
                name: .clipboardCheckIntervalChanged,
                object: nil
            )
        }
    }

    /// Play sound on copy
    var enableSound: Bool {
        didSet {
            defaults.set(enableSound, forKey: Keys.enableSound)
        }
    }

    /// Enable iCloud sync between devices
    var enableiCloudSync: Bool {
        didSet {
            defaults.set(enableiCloudSync, forKey: Keys.enableiCloudSync)
            NotificationCenter.default.post(
                name: .iCloudSyncSettingChanged,
                object: nil
            )
        }
    }

    // MARK: - Appearance Settings

    /// Show app icon in menu bar
    var showInMenuBar: Bool {
        didSet {
            defaults.set(showInMenuBar, forKey: Keys.showInMenuBar)
        }
    }

    /// Show app icon in dock
    var showInDock: Bool {
        didSet {
            defaults.set(showInDock, forKey: Keys.showInDock)
            updateDockVisibility()
        }
    }

    /// Show content preview in list
    var showPreview: Bool {
        didSet {
            defaults.set(showPreview, forKey: Keys.showPreview)
        }
    }

    /// Maximum preview length in characters
    var previewMaxLength: Int {
        didSet {
            defaults.set(previewMaxLength, forKey: Keys.previewMaxLength)
        }
    }

    /// Show source app info
    var showSourceApp: Bool {
        didSet {
            defaults.set(showSourceApp, forKey: Keys.showSourceApp)
        }
    }

    // MARK: - Behavior Settings

    /// Launch at login
    var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    /// Paste automatically after selecting item
    var pasteAutomatically: Bool {
        didSet {
            defaults.set(pasteAutomatically, forKey: Keys.pasteAutomatically)
        }
    }

    /// Remove formatting by default when pasting
    var removeFormattingByDefault: Bool {
        didSet {
            defaults.set(removeFormattingByDefault, forKey: Keys.removeFormattingByDefault)
        }
    }

    /// Search mode (fuzzy, exact, regex)
    var searchMode: SearchMode {
        didSet {
            defaults.set(searchMode.rawValue, forKey: Keys.searchMode)
        }
    }

    /// Trim whitespace from copied text
    var trimWhitespace: Bool {
        didSet {
            defaults.set(trimWhitespace, forKey: Keys.trimWhitespace)
        }
    }

    /// Ignore consecutive duplicate copies
    var ignoreConsecutiveDuplicates: Bool {
        didSet {
            defaults.set(ignoreConsecutiveDuplicates, forKey: Keys.ignoreConsecutiveDuplicates)
        }
    }

    /// Enable duplicate detection
    var duplicateDetection: DuplicateDetection {
        didSet {
            defaults.set(duplicateDetection.rawValue, forKey: Keys.duplicateDetection)
        }
    }

    // MARK: - Privacy & Security Settings

    /// Enable password manager detection
    var enablePasswordManagerDetection: Bool {
        didSet {
            defaults.set(enablePasswordManagerDetection, forKey: Keys.enablePasswordManagerDetection)
        }
    }

    /// Clear history on app quit
    var clearHistoryOnQuit: Bool {
        didSet {
            defaults.set(clearHistoryOnQuit, forKey: Keys.clearHistoryOnQuit)
        }
    }

    /// Enable encryption for stored data
    var enableEncryption: Bool {
        didSet {
            defaults.set(enableEncryption, forKey: Keys.enableEncryption)
        }
    }

    /// Patterns to detect sensitive content
    var sensitiveContentPatterns: [String] {
        didSet {
            defaults.set(sensitiveContentPatterns, forKey: Keys.sensitiveContentPatterns)
        }
    }

    /// Auto-delete sensitive items after (in seconds, 0 = never)
    var autoDeleteSensitiveAfter: TimeInterval {
        didSet {
            defaults.set(autoDeleteSensitiveAfter, forKey: Keys.autoDeleteSensitiveAfter)
        }
    }

    // MARK: - Ignored Apps & Patterns

    /// Bundle IDs of apps to ignore
    var ignoredApps: Set<String> {
        didSet {
            defaults.set(Array(ignoredApps), forKey: Keys.ignoredApps)
        }
    }

    /// Regex patterns for content to ignore
    var ignoredPatterns: [String] {
        didSet {
            defaults.set(ignoredPatterns, forKey: Keys.ignoredPatterns)
        }
    }

    // MARK: - Size Limits

    /// Maximum image size to store (in bytes)
    var imageMaxSize: Int {
        didSet {
            defaults.set(imageMaxSize, forKey: Keys.imageMaxSize)
        }
    }

    /// Ignore items larger than threshold
    var ignoreLargeItems: Bool {
        didSet {
            defaults.set(ignoreLargeItems, forKey: Keys.ignoreLargeItems)
        }
    }

    /// Large item threshold (in bytes)
    var largeItemThreshold: Int {
        didSet {
            defaults.set(largeItemThreshold, forKey: Keys.largeItemThreshold)
        }
    }

    // MARK: - Hotkey

    /// Global hotkey string representation
    var globalHotkey: String {
        didSet {
            defaults.set(globalHotkey, forKey: Keys.globalHotkey)
            NotificationCenter.default.post(
                name: .globalHotkeyChanged,
                object: nil
            )
        }
    }

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Register defaults
        let defaultValues: [String: Any] = [
            Keys.maxHistorySize: 200,
            Keys.clipboardCheckInterval: 0.5,
            Keys.enableSound: false,
            Keys.enableiCloudSync: true,
            Keys.showInMenuBar: true,
            Keys.showInDock: false,
            Keys.launchAtLogin: false,
            Keys.pasteAutomatically: false,
            Keys.removeFormattingByDefault: false,
            Keys.searchMode: SearchMode.fuzzy.rawValue,
            Keys.showPreview: true,
            Keys.previewMaxLength: 100,
            Keys.enablePasswordManagerDetection: true,
            Keys.clearHistoryOnQuit: false,
            Keys.globalHotkey: "shift+cmd+v",
            Keys.imageMaxSize: 5_000_000, // 5MB
            Keys.ignoreLargeItems: true,
            Keys.largeItemThreshold: 10_000_000, // 10MB
            Keys.duplicateDetection: DuplicateDetection.consecutive.rawValue,
            Keys.trimWhitespace: false,
            Keys.ignoreConsecutiveDuplicates: true,
            Keys.showSourceApp: true,
            Keys.enableEncryption: false,
            Keys.sensitiveContentPatterns: [
                "\\b\\d{16}\\b", // Credit card numbers
                "\\b\\d{3}-\\d{2}-\\d{4}\\b", // SSN
                "password\\s*[:=]\\s*\\S+", // Passwords
                "api[_-]?key\\s*[:=]\\s*\\S+", // API keys
                "secret\\s*[:=]\\s*\\S+"  // Secrets
            ],
            Keys.autoDeleteSensitiveAfter: 3600, // 1 hour
            Keys.ignoredApps: [] as [String],
            Keys.ignoredPatterns: [] as [String]
        ]

        defaults.register(defaults: defaultValues)

        // Load values
        self.maxHistorySize = defaults.integer(forKey: Keys.maxHistorySize)
        self.clipboardCheckInterval = defaults.double(forKey: Keys.clipboardCheckInterval)
        self.enableSound = defaults.bool(forKey: Keys.enableSound)
        self.enableiCloudSync = defaults.bool(forKey: Keys.enableiCloudSync)
        self.showInMenuBar = defaults.bool(forKey: Keys.showInMenuBar)
        self.showInDock = defaults.bool(forKey: Keys.showInDock)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.pasteAutomatically = defaults.bool(forKey: Keys.pasteAutomatically)
        self.removeFormattingByDefault = defaults.bool(forKey: Keys.removeFormattingByDefault)
        self.searchMode = SearchMode(rawValue: defaults.string(forKey: Keys.searchMode) ?? "") ?? .fuzzy
        self.showPreview = defaults.bool(forKey: Keys.showPreview)
        self.previewMaxLength = defaults.integer(forKey: Keys.previewMaxLength)
        self.enablePasswordManagerDetection = defaults.bool(forKey: Keys.enablePasswordManagerDetection)
        self.clearHistoryOnQuit = defaults.bool(forKey: Keys.clearHistoryOnQuit)
        self.globalHotkey = defaults.string(forKey: Keys.globalHotkey) ?? "shift+cmd+v"
        self.imageMaxSize = defaults.integer(forKey: Keys.imageMaxSize)
        self.ignoreLargeItems = defaults.bool(forKey: Keys.ignoreLargeItems)
        self.largeItemThreshold = defaults.integer(forKey: Keys.largeItemThreshold)
        self.duplicateDetection = DuplicateDetection(rawValue: defaults.string(forKey: Keys.duplicateDetection) ?? "") ?? .consecutive
        self.trimWhitespace = defaults.bool(forKey: Keys.trimWhitespace)
        self.ignoreConsecutiveDuplicates = defaults.bool(forKey: Keys.ignoreConsecutiveDuplicates)
        self.showSourceApp = defaults.bool(forKey: Keys.showSourceApp)
        self.enableEncryption = defaults.bool(forKey: Keys.enableEncryption)
        self.sensitiveContentPatterns = defaults.stringArray(forKey: Keys.sensitiveContentPatterns) ?? []
        self.autoDeleteSensitiveAfter = defaults.double(forKey: Keys.autoDeleteSensitiveAfter)
        self.ignoredApps = Set(defaults.stringArray(forKey: Keys.ignoredApps) ?? [])
        self.ignoredPatterns = defaults.stringArray(forKey: Keys.ignoredPatterns) ?? []
    }

    // MARK: - Helper Methods

    private func updateDockVisibility() {
        #if os(macOS)
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        #endif
    }

    private func updateLaunchAtLogin() {
        #if os(macOS)
        // Use SMAppService on macOS 13+
        if #available(macOS 13.0, *) {
            // Implementation uses SMAppService
        }
        #endif
    }

    /// Check if an app should be ignored
    func shouldIgnoreApp(_ bundleID: String) -> Bool {
        ignoredApps.contains(bundleID)
    }

    /// Check if content matches any ignored pattern
    func shouldIgnoreContent(_ content: String) -> Bool {
        for pattern in ignoredPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(content.startIndex..., in: content)
                if regex.firstMatch(in: content, range: range) != nil {
                    return true
                }
            }
        }
        return false
    }

    /// Check if content appears sensitive
    func isSensitiveContent(_ content: String) -> Bool {
        for pattern in sensitiveContentPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(content.startIndex..., in: content)
                if regex.firstMatch(in: content, range: range) != nil {
                    return true
                }
            }
        }
        return false
    }

    /// Add app to ignore list
    func addIgnoredApp(_ bundleID: String) {
        ignoredApps.insert(bundleID)
    }

    /// Remove app from ignore list
    func removeIgnoredApp(_ bundleID: String) {
        ignoredApps.remove(bundleID)
    }

    /// Reset all settings to defaults
    func resetToDefaults() {
        let domain = Bundle.main.bundleIdentifier ?? "com.clipboard.manager"
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
    }
}

// MARK: - Supporting Types

enum SearchMode: String, CaseIterable, Identifiable {
    case fuzzy
    case exact
    case regex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fuzzy: return "Fuzzy"
        case .exact: return "Exact Match"
        case .regex: return "Regular Expression"
        }
    }
}

enum DuplicateDetection: String, CaseIterable, Identifiable {
    case none
    case consecutive
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Disabled"
        case .consecutive: return "Consecutive Only"
        case .all: return "All Duplicates"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let clipboardCheckIntervalChanged = Notification.Name("clipboardCheckIntervalChanged")
    static let iCloudSyncSettingChanged = Notification.Name("iCloudSyncSettingChanged")
    static let globalHotkeyChanged = Notification.Name("globalHotkeyChanged")
}

// MARK: - Known Password Managers

struct KnownPasswordManagers {
    static let bundleIDs: Set<String> = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx",
        "com.bitwarden.desktop",
        "com.lastpass.LastPass",
        "com.dashlane.dashlanephonefinal",
        "com.keepersecurity.keeper",
        "com.nordpass.macos.nordpass",
        "com.roboform.roboform-macos",
        "com.enpass.Enpass",
        "org.nickvision.passwords",
        "de.heinekingmedia.macssystemmenu.PasswordDepot",
        "com.apple.KeychainAccess"
    ]

    static func isPasswordManager(_ bundleID: String) -> Bool {
        bundleIDs.contains(bundleID)
    }
}
