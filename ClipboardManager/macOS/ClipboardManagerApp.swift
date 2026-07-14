import SwiftUI
import SwiftData
import ServiceManagement

// MARK: - macOS App Entry Point

@main
struct ClipboardManagerApp: App {
    // MARK: - Properties

    @StateObject private var appState = AppState()

    // MARK: - Body

    var body: some Scene {
        // Settings window
        Settings {
            SettingsView(settings: appState.settings)
        }

        // Menu bar extra (the main interface)
        MenuBarExtra {
            MenuBarContentView(appState: appState)
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    // MARK: - Properties

    let settings: AppSettings
    let dataStore: DataStore
    let clipboardMonitor: ClipboardMonitor
    let hotkeyManager: HotkeyManager
    var menuBarManager: MenuBarManager?

    @Published var isRunning = false

    // MARK: - Initialization

    init() {
        // Initialize settings
        self.settings = AppSettings()

        // Initialize data store
        do {
            self.dataStore = try DataStore(settings: settings)
        } catch {
            fatalError("Failed to initialize data store: \(error)")
        }

        // Initialize clipboard monitor
        self.clipboardMonitor = ClipboardMonitor(settings: settings)

        // Initialize hotkey manager
        self.hotkeyManager = HotkeyManager(settings: settings)

        // Setup
        setup()
    }

    // MARK: - Setup

    private func setup() {
        // Set clipboard monitor delegate
        clipboardMonitor.delegate = self

        // Start monitoring
        clipboardMonitor.start()

        // Register hotkey
        hotkeyManager.register()
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.togglePopover()
        }

        // Update dock visibility
        updateDockVisibility()

        // Setup launch at login
        setupLaunchAtLogin()

        isRunning = true

        // Listen for settings changes
        NotificationCenter.default.addObserver(
            forName: .openSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openSettings()
        }
    }

    // MARK: - Actions

    func togglePopover() {
        menuBarManager?.togglePopover()
    }

    func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func updateDockVisibility() {
        if settings.showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func setupLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if settings.launchAtLogin {
                    if service.status != .enabled {
                        try service.register()
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                    }
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        if settings.clearHistoryOnQuit {
            try? dataStore.clearHistory(keepPinned: true)
        }

        clipboardMonitor.stop()
        hotkeyManager.unregister()
    }
}

// MARK: - Clipboard Monitor Delegate

extension AppState: ClipboardMonitorDelegate {
    func clipboardMonitor(_ monitor: ClipboardMonitor, didCaptureItem item: ClipboardItem) {
        Task { @MainActor in
            do {
                try dataStore.addItem(item)
            } catch {
                print("Failed to save clipboard item: \(error)")
            }
        }
    }

    func clipboardMonitor(_ monitor: ClipboardMonitor, didEncounterError error: ClipboardMonitorError) {
        // Log errors but don't show to user (would be too noisy)
        print("Clipboard monitor error: \(error.localizedDescription)")
    }
}

// MARK: - Menu Bar Content View

struct MenuBarContentView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ClipboardHistoryView(
            dataStore: appState.dataStore,
            settings: appState.settings,
            clipboardMonitor: appState.clipboardMonitor,
            onDismiss: { }
        )
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    @State private var selectedTab = "general"

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag("general")

            AppearanceSettingsView(settings: settings)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag("appearance")

            BehaviorSettingsView(settings: settings)
                .tabItem {
                    Label("Behavior", systemImage: "hand.tap")
                }
                .tag("behavior")

            PrivacySettingsView(settings: settings)
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }
                .tag("privacy")

            IgnoredAppsSettingsView(settings: settings)
                .tabItem {
                    Label("Ignored", systemImage: "nosign")
                }
                .tag("ignored")

            AdvancedSettingsView(settings: settings)
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
                .tag("advanced")
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("History Size")
                    Spacer()
                    TextField("", value: $settings.maxHistorySize, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    Stepper("", value: $settings.maxHistorySize, in: 10...999)
                        .labelsHidden()
                }

                Toggle("Launch at Login", isOn: $settings.launchAtLogin)

                Toggle("iCloud Sync", isOn: $settings.enableiCloudSync)
            }

            Section("Hotkey") {
                HStack {
                    Text("Global Shortcut")
                    Spacer()
                    HotkeyRecorderView(hotkeyString: $settings.globalHotkey)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Show in Menu Bar", isOn: $settings.showInMenuBar)
                Toggle("Show in Dock", isOn: $settings.showInDock)
            }

            Section("Preview") {
                Toggle("Show Preview", isOn: $settings.showPreview)

                HStack {
                    Text("Preview Length")
                    Spacer()
                    TextField("", value: $settings.previewMaxLength, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Show Source App", isOn: $settings.showSourceApp)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Behavior Settings

struct BehaviorSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Pasting") {
                Toggle("Paste Automatically", isOn: $settings.pasteAutomatically)
                Toggle("Remove Formatting by Default", isOn: $settings.removeFormattingByDefault)
            }

            Section("Content Processing") {
                Toggle("Trim Whitespace", isOn: $settings.trimWhitespace)
                Toggle("Ignore Consecutive Duplicates", isOn: $settings.ignoreConsecutiveDuplicates)

                Picker("Duplicate Detection", selection: $settings.duplicateDetection) {
                    ForEach(DuplicateDetection.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                Picker("Search Mode", selection: $settings.searchMode) {
                    ForEach(SearchMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("Sound") {
                Toggle("Play Sound on Copy", isOn: $settings.enableSound)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Password Managers") {
                Toggle("Detect Password Manager Content", isOn: $settings.enablePasswordManagerDetection)

                Text("When enabled, clipboard content from password managers like 1Password and Bitwarden will not be saved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Sensitive Content") {
                Toggle("Auto-Delete Sensitive Content", isOn: .constant(settings.autoDeleteSensitiveAfter > 0))

                if settings.autoDeleteSensitiveAfter > 0 {
                    Picker("Delete After", selection: $settings.autoDeleteSensitiveAfter) {
                        Text("1 Hour").tag(TimeInterval(3600))
                        Text("4 Hours").tag(TimeInterval(14400))
                        Text("24 Hours").tag(TimeInterval(86400))
                    }
                }
            }

            Section("On Quit") {
                Toggle("Clear History on Quit", isOn: $settings.clearHistoryOnQuit)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Ignored Apps Settings

struct IgnoredAppsSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var newBundleID = ""

    var body: some View {
        VStack(alignment: .leading) {
            Text("Ignored Applications")
                .font(.headline)

            List {
                ForEach(Array(settings.ignoredApps).sorted(), id: \.self) { bundleID in
                    HStack {
                        Text(bundleID)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button(action: { settings.removeIgnoredApp(bundleID) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 200)

            HStack {
                TextField("Bundle ID (e.g., com.apple.Safari)", text: $newBundleID)
                    .textFieldStyle(.roundedBorder)

                Button("Add") {
                    if !newBundleID.isEmpty {
                        settings.addIgnoredApp(newBundleID)
                        newBundleID = ""
                    }
                }
                .disabled(newBundleID.isEmpty)
            }

            Divider()
                .padding(.vertical)

            Text("Ignored Patterns (Regex)")
                .font(.headline)

            List {
                ForEach(settings.ignoredPatterns, id: \.self) { pattern in
                    Text(pattern)
                        .font(.system(.body, design: .monospaced))
                }
                .onDelete { indexSet in
                    settings.ignoredPatterns.remove(atOffsets: indexSet)
                }
            }
            .frame(height: 100)
        }
        .padding()
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Clipboard Monitoring") {
                HStack {
                    Text("Check Interval")
                    Spacer()
                    TextField("", value: $settings.clipboardCheckInterval, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    Text("seconds")
                        .foregroundColor(.secondary)
                }
            }

            Section("Size Limits") {
                Toggle("Ignore Large Items", isOn: $settings.ignoreLargeItems)

                if settings.ignoreLargeItems {
                    HStack {
                        Text("Size Threshold")
                        Spacer()
                        Picker("", selection: $settings.largeItemThreshold) {
                            Text("1 MB").tag(1_000_000)
                            Text("5 MB").tag(5_000_000)
                            Text("10 MB").tag(10_000_000)
                            Text("50 MB").tag(50_000_000)
                        }
                        .frame(width: 100)
                    }
                }

                HStack {
                    Text("Max Image Size")
                    Spacer()
                    Picker("", selection: $settings.imageMaxSize) {
                        Text("1 MB").tag(1_000_000)
                        Text("5 MB").tag(5_000_000)
                        Text("10 MB").tag(10_000_000)
                    }
                    .frame(width: 100)
                }
            }

            Section {
                Button("Reset All Settings") {
                    settings.resetToDefaults()
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
    }
}
