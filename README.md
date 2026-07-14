# Clipboard Manager

A cross-platform clipboard manager for macOS, iOS, and iPadOS with iCloud sync.

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
- **Sensitive Content Detection** - Automatically detect and flag credit cards, SSNs, API keys, etc.
- **Auto-Delete Sensitive Items** - Optionally auto-delete sensitive content after a set time
- **Encryption** - Encrypt stored clipboard data with AES-256-GCM
- **Biometric Lock** - Protect the app with Face ID / Touch ID
- **Password Manager Exclusion** - Ignore concealed clipboard content from password managers

## Project Structure

```
ClipboardManager/
├── Shared/                          # Shared code for all platforms
│   ├── Models/
│   │   ├── ClipboardItem.swift      # Main data model
│   │   └── AppSettings.swift        # Settings and preferences
│   └── Services/
│       ├── DataStore.swift          # SwiftData persistence layer
│       └── SecurityManager.swift    # Encryption and security
│
├── macOS/                           # macOS-specific code
│   ├── ClipboardManagerApp.swift    # App entry point
│   ├── Views/
│   │   └── MenuBarView.swift        # Menu bar UI
│   ├── Services/
│   │   ├── ClipboardMonitor.swift   # Clipboard monitoring
│   │   └── HotkeyManager.swift      # Global hotkey handling
│   ├── Info.plist
│   └── ClipboardManager.entitlements
│
├── iOS/                             # iOS/iPadOS-specific code
│   ├── ClipboardManageriOSApp.swift # App entry point
│   ├── Views/
│   │   └── ClipboardListView.swift  # Main list UI
│   ├── Services/
│   │   └── iOSClipboardHandler.swift # iOS clipboard handling
│   ├── KeyboardExtension/           # Custom keyboard
│   │   ├── KeyboardViewController.swift
│   │   └── Info.plist
│   ├── Info.plist
│   └── ClipboardManager.entitlements
│
└── README.md
```

## Requirements

- **macOS**: macOS 14.0 (Sonoma) or later
- **iOS/iPadOS**: iOS 17.0 or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode and create a new project
2. Select "Multiplatform" > "App"
3. Name it "ClipboardManager"
4. Choose SwiftUI for the interface
5. Enable "Use SwiftData"

### 2. Add Source Files

Copy all the Swift files from this repository into your Xcode project:
- Add `Shared/` files to both macOS and iOS targets
- Add `macOS/` files to the macOS target only
- Add `iOS/` files to the iOS target only

### 3. Configure Targets

#### macOS Target
1. Set deployment target to macOS 14.0
2. Add `Info.plist` content
3. Add entitlements file
4. Enable "App Sandbox" in Signing & Capabilities
5. Add "iCloud" capability with CloudKit
6. Add "Accessibility" capability (for auto-paste)

#### iOS Target
1. Set deployment target to iOS 17.0
2. Add `Info.plist` content
3. Add entitlements file
4. Add "iCloud" capability with CloudKit
5. Add "App Groups" capability with `group.com.clipboard.manager`
6. Add "Keychain Sharing" capability

#### Keyboard Extension Target
1. Create new target: File > New > Target > Keyboard Extension
2. Name it "ClipboardKeyboard"
3. Add `KeyboardViewController.swift`
4. Add `Info.plist` content
5. Add "App Groups" capability with same group identifier

### 4. Configure iCloud

1. Sign in to your Apple Developer account
2. Enable CloudKit for your App ID
3. Create a CloudKit container: `iCloud.com.clipboard.manager`
4. Add the container to all targets

### 5. Build and Run

```bash
# Build for macOS
xcodebuild -scheme ClipboardManager -destination 'platform=macOS' build

# Build for iOS
xcodebuild -scheme ClipboardManager -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## Usage

### macOS

1. Launch the app - it appears in the menu bar
2. Press **Shift+Cmd+V** to open clipboard history
3. Type to search, press Enter to paste
4. Use **Opt+Enter** to paste without formatting
5. Use **Opt+P** to pin/unpin items

### iOS/iPadOS

1. Launch the app to view clipboard history
2. Pull down to refresh and capture current clipboard
3. Tap an item to view details
4. Swipe left to delete or pin
5. Enable the keyboard extension in Settings > General > Keyboard

### Keyboard Shortcuts (macOS)

| Shortcut | Action |
|----------|--------|
| Shift+Cmd+V | Open clipboard history |
| Enter | Copy and paste selected item |
| Opt+Enter | Paste without formatting |
| Opt+P | Toggle pin |
| Opt+Delete | Delete item |
| Cmd+1-9 | Quick paste pinned items |
| Up/Down | Navigate items |
| Esc | Close |

## Configuration

### Settings

Access settings from the menu bar icon (macOS) or Settings tab (iOS):

- **Max History Size**: 10-999 items
- **iCloud Sync**: Enable/disable sync between devices
- **Auto-Paste**: Paste immediately after selection
- **Ignore Duplicates**: Skip consecutive duplicate copies
- **Password Manager Detection**: Ignore secure clipboard content
- **Clear on Quit**: Delete history when app closes

### Ignored Apps (macOS)

Add bundle IDs to ignore specific applications:
- `com.1password.1password`
- `com.bitwarden.desktop`
- Custom apps by bundle ID

### Ignored Patterns

Add regex patterns to ignore specific content:
- Credit cards: `\b\d{16}\b`
- Passwords: `password\s*[:=]\s*\S+`

## Privacy & Security

- **Local Storage**: All data stored locally using SwiftData
- **iCloud Sync**: Optional, uses CloudKit with end-to-end encryption
- **No Analytics**: No data collection or tracking
- **Open Source**: Full transparency of code

## Edge Cases Handled

1. **Large Content**: Configurable size limits for images and text
2. **Password Managers**: Detects and ignores concealed pasteboard types
3. **Duplicates**: Consecutive and global duplicate detection
4. **Sensitive Content**: Auto-detection of credit cards, SSNs, API keys
5. **Memory Management**: Efficient handling of large history
6. **Concurrent Access**: Thread-safe clipboard monitoring
7. **App Lifecycle**: Proper handling of background/foreground transitions
8. **iOS Privacy**: Respects iOS clipboard permission requirements
9. **Network Failures**: Graceful handling of iCloud sync issues
10. **Data Migration**: Supports future schema migrations

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## Acknowledgments

Inspired by [Maccy](https://github.com/p0deje/Maccy) - a great clipboard manager for macOS.
