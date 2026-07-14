import Foundation
import AppKit
import Carbon
import Combine

// MARK: - Hotkey Manager

/// Manages global keyboard shortcuts on macOS
final class HotkeyManager: ObservableObject {
    // MARK: - Properties

    @Published private(set) var isEnabled = false
    @Published private(set) var currentHotkey: HotkeyCombo?

    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private var hotkeyID: EventHotKeyID

    private let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    // Callback when hotkey is pressed
    var onHotkeyPressed: (() -> Void)?

    // MARK: - Initialization

    init(settings: AppSettings) {
        self.settings = settings
        self.hotkeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1) // "CLIP"

        setupNotifications()
    }

    deinit {
        unregister()
    }

    // MARK: - Setup

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .globalHotkeyChanged)
            .sink { [weak self] _ in
                self?.updateHotkey()
            }
            .store(in: &cancellables)
    }

    // MARK: - Registration

    /// Register the global hotkey
    func register() {
        guard let combo = parseHotkeyString(settings.globalHotkey) else {
            print("Failed to parse hotkey: \(settings.globalHotkey)")
            return
        }

        unregister() // Unregister any existing hotkey

        currentHotkey = combo

        // Install event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerResult = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotkey()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard handlerResult == noErr else {
            print("Failed to install event handler: \(handlerResult)")
            return
        }

        // Register hotkey
        let registerResult = RegisterEventHotKey(
            UInt32(combo.keyCode),
            UInt32(combo.modifiers),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        guard registerResult == noErr else {
            print("Failed to register hotkey: \(registerResult)")
            return
        }

        isEnabled = true
    }

    /// Unregister the global hotkey
    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }

        isEnabled = false
        currentHotkey = nil
    }

    /// Update hotkey from settings
    func updateHotkey() {
        register()
    }

    // MARK: - Handler

    private func handleHotkey() {
        DispatchQueue.main.async { [weak self] in
            self?.onHotkeyPressed?()
        }
    }

    // MARK: - Parsing

    /// Parse hotkey string like "shift+cmd+v" into HotkeyCombo
    private func parseHotkeyString(_ string: String) -> HotkeyCombo? {
        let components = string.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }

        var modifiers: UInt32 = 0
        var keyCode: Int = -1

        for component in components {
            switch component {
            case "cmd", "command":
                modifiers |= UInt32(cmdKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            case "opt", "option", "alt":
                modifiers |= UInt32(optionKey)
            case "ctrl", "control":
                modifiers |= UInt32(controlKey)
            default:
                // This is the key
                if let code = keyCodeForCharacter(component) {
                    keyCode = code
                }
            }
        }

        guard keyCode >= 0 else { return nil }

        return HotkeyCombo(
            keyCode: keyCode,
            modifiers: modifiers,
            displayString: string
        )
    }

    /// Get key code for a character
    private func keyCodeForCharacter(_ char: String) -> Int? {
        let keyCodes: [String: Int] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
            "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45,
            "o": 31, "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32,
            "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21,
            "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
            "space": 49, "return": 36, "enter": 76, "tab": 48,
            "escape": 53, "delete": 51, "backspace": 51,
            "up": 126, "down": 125, "left": 123, "right": 124,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118,
            "f5": 96, "f6": 97, "f7": 98, "f8": 100,
            "f9": 101, "f10": 109, "f11": 103, "f12": 111
        ]

        return keyCodes[char.lowercased()]
    }
}

// MARK: - Hotkey Combo

struct HotkeyCombo {
    let keyCode: Int
    let modifiers: UInt32
    let displayString: String

    var formattedString: String {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 {
            parts.append("^")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("^")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("^")
        }
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("^")
        }

        // Add key character
        if let char = characterForKeyCode(keyCode) {
            parts.append(char.uppercased())
        }

        return parts.joined()
    }

    private func characterForKeyCode(_ code: Int) -> String? {
        let characters: [Int: String] = [
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G",
            4: "H", 34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N",
            31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U",
            9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
            49: "Space", 36: "Return", 53: "Esc"
        ]

        return characters[code]
    }
}

// MARK: - Hotkey Recorder View

struct HotkeyRecorderView: View {
    @Binding var hotkeyString: String
    @State private var isRecording = false
    @State private var recordedKeys: Set<String> = []

    var body: some View {
        HStack {
            Text(hotkeyString.isEmpty ? "Click to record" : hotkeyString)
                .frame(minWidth: 150)
                .padding(8)
                .background(isRecording ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                )

            if !hotkeyString.isEmpty {
                Button(action: { hotkeyString = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .onTapGesture {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        recordedKeys = []

        // Add local event monitor for key recording
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if isRecording {
                handleKeyEvent(event)
                return nil
            }
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        var parts: [String] = []

        if event.modifierFlags.contains(.command) {
            parts.append("cmd")
        }
        if event.modifierFlags.contains(.shift) {
            parts.append("shift")
        }
        if event.modifierFlags.contains(.option) {
            parts.append("opt")
        }
        if event.modifierFlags.contains(.control) {
            parts.append("ctrl")
        }

        if let chars = event.charactersIgnoringModifiers?.lowercased() {
            parts.append(chars)
        }

        hotkeyString = parts.joined(separator: "+")
        isRecording = false
    }
}
