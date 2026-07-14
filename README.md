# ClipboardManager

A cross-platform clipboard manager for macOS, iOS, and iPadOS with iCloud sync. Inspired by [Maccy](https://github.com/p0deje/Maccy).

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS%20%7C%20iPadOS-blue)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### Core Features
- **Clipboard History** - Save and search through your clipboard history
- **iCloud Sync** - Sync clipboard history across all your Apple devices
- **Fuzzy Search** - Find items quickly with intelligent fuzzy matching
- **Pin Items** - Keep frequently used items always accessible
- **Multiple Content Types** - Support for text, images, files, URLs, and more

### macOS Features
- **Menu Bar App** - Quick access from the menu bar
- **Global Hotkey** - Open with customizable keyboard shortcut (default: Shift+Cmd+V)
- **Auto-Paste** - Optionally paste immediately after selecting an item
- **Password Manager Detection** - Automatically ignore sensitive content from 1Password, Bitwarden, etc.

### iOS/iPadOS Features
- **Keyboard Extension** - Access clipboard history directly from any app
- **Share Extension** - Save content from any app to clipboard history
- **Widgets** - Quick access to recent items from home screen
- **Shortcuts Integration** - Automate clipboard operations with Siri Shortcuts

### Security Features
- **Sensitive Content Detection** - Automatically detect and flag credit cards, SSNs, API keys
- **Auto-Delete Sensitive Items** - Optionally auto-delete sensitive content after a set time
- **Encryption** - Encrypt stored clipboard data with AES-256-GCM
- **Biometric Lock** - Protect the app with Face ID / Touch ID
- **Password Manager Exclusion** - Ignore concealed clipboard content from password managers

## Quick Start

### Prerequisites
- macOS 14.0+ (Sonoma) for macOS app
- iOS 17.0+ for iOS app
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (installed automatically)

### Build from Source

```bash
# Clone the repository
git clone https://github.com/hselbi/ClipboardManager.git
cd ClipboardManager/ClipboardManager

# Install XcodeGen and generate Xcode project
make setup
make generate

# Open in Xcode
make open
```

### Build Commands

```bash
# Build macOS app
make build-macos

# Build iOS app (Simulator)
make build-ios

# Clean build artifacts
make clean

# See all commands
make help
```

## Project Structure

```
ClipboardManager/
├── Shared/                          # Shared code for all platforms
│   ├── Models/
│   │   ├── ClipboardItem.swift      # Main data model (SwiftData)
│   │   └── AppSettings.swift        # Settings and preferences
│   ├── Services/
│   │   ├── DataStore.swift          # SwiftData persistence + iCloud
│   │   └── SecurityManager.swift    # Encryption and biometrics
│   └── Assets.xcassets/             # Shared assets
│
├── macOS/                           # macOS-specific code
│   ├── ClipboardManagerApp.swift    # App entry point + settings UI
│   ├── Views/
│   │   └── MenuBarView.swift        # Menu bar popup UI
│   ├── Services/
│   │   ├── ClipboardMonitor.swift   # Clipboard polling
│   │   └── HotkeyManager.swift      # Global hotkey handling
│   └── Info.plist + Entitlements
│
├── iOS/                             # iOS/iPadOS-specific code
│   ├── ClipboardManageriOSApp.swift # iOS app entry point
│   ├── Views/
│   │   └── ClipboardListView.swift  # Main list UI
│   ├── Services/
│   │   └── iOSClipboardHandler.swift
│   ├── KeyboardExtension/           # Custom keyboard
│   ├── ShareExtension/              # Share sheet integration
│   ├── WidgetExtension/             # Home screen widgets
│   └── Info.plist + Entitlements
│
├── project.yml                      # XcodeGen configuration
├── Makefile                         # Build automation
└── README.md
```

## Configuration

### Xcode Setup

1. **Generate Project**: Run `make generate` to create `ClipboardManager.xcodeproj`

2. **Signing**: In Xcode, select your development team for all targets:
   - ClipboardManager-macOS
   - ClipboardManager-iOS
   - ClipboardKeyboard
   - ClipboardShare
   - ClipboardWidget

3. **Capabilities**: Enable these capabilities (already configured in entitlements):
   - **iCloud** (CloudKit) - for sync
   - **App Groups** - for extensions (`group.com.hselbi.clipboardmanager`)
   - **Keychain Sharing** - for secure storage

4. **Bundle IDs**: Update bundle IDs if needed:
   - macOS: `com.hselbi.clipboardmanager`
   - iOS: `com.hselbi.clipboardmanager`
   - Keyboard: `com.hselbi.clipboardmanager.keyboard`
   - Share: `com.hselbi.clipboardmanager.share`
   - Widget: `com.hselbi.clipboardmanager.widget`

### App Settings

| Setting | Description | Default |
|---------|-------------|---------|
| Max History Size | Number of items to keep | 200 |
| iCloud Sync | Sync across devices | On |
| Auto-Paste | Paste after selection | Off |
| Password Detection | Ignore password managers | On |
| Clear on Quit | Delete history on exit | Off |
| Global Hotkey | Keyboard shortcut | ⇧⌘V |

## Keyboard Shortcuts (macOS)

| Shortcut | Action |
|----------|--------|
| ⇧⌘V | Open clipboard history |
| ↵ | Copy and paste selected item |
| ⌥↵ | Paste without formatting |
| ⌥P | Toggle pin |
| ⌥⌫ | Delete item |
| ⌘1-9 | Quick paste pinned items |
| ↑↓ | Navigate items |
| ⎋ | Close |

## Edge Cases Handled

| Edge Case | Solution |
|-----------|----------|
| Password managers | Detects concealed pasteboard types (1Password, Bitwarden, etc.) |
| Large content | Configurable size limits, image compression |
| Duplicates | Consecutive & global duplicate detection |
| Sensitive data | Auto-detects credit cards, SSNs, API keys, private keys |
| iOS privacy | Respects iOS 14+ paste notifications, iOS 16+ permissions |
| Memory | Efficient polling, external storage for images |
| Sync failures | Graceful iCloud error handling |
| Background | Proper lifecycle handling on both platforms |

## Privacy & Security

- **Local Storage**: All data stored locally using SwiftData
- **iCloud Sync**: Optional, uses CloudKit with end-to-end encryption
- **No Analytics**: No data collection or tracking
- **Open Source**: Full transparency of code

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by [Maccy](https://github.com/p0deje/Maccy) - an excellent clipboard manager for macOS
- Built with SwiftUI, SwiftData, and CloudKit
