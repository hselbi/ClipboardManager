# ClipboardManager - Project Context for Claude

> **INSTRUCTION**: When starting a new conversation, tell Claude:
> "Read the file at ~/Desktop/Maccy-copy/CLAUDE_CONTEXT.md and analyze my ClipboardManager project"

---

## Project Summary

**Name**: ClipboardManager
**Type**: Cross-platform clipboard manager (macOS, iOS, iPadOS)
**Repository**: https://github.com/hselbi/ClipboardManager
**Location**: `/Users/selbihafid/Desktop/Maccy-copy/`
**Inspired by**: [Maccy](https://github.com/p0deje/Maccy)

---

## Project Structure

```
/Users/selbihafid/Desktop/Maccy-copy/
├── ClipboardManager/                    # Main project folder
│   ├── Shared/                          # Shared code (macOS + iOS)
│   │   ├── Models/
│   │   │   ├── ClipboardItem.swift      # SwiftData model - clipboard item
│   │   │   └── AppSettings.swift        # All app settings (50+ options)
│   │   ├── Services/
│   │   │   ├── DataStore.swift          # SwiftData + iCloud sync
│   │   │   └── SecurityManager.swift    # Encryption, biometrics, sensitive detection
│   │   └── Assets.xcassets/             # App icons, colors
│   │
│   ├── macOS/                           # macOS-specific
│   │   ├── ClipboardManagerApp.swift    # App entry point + Settings UI
│   │   ├── Views/
│   │   │   └── MenuBarView.swift        # Menu bar popup, search, list
│   │   ├── Services/
│   │   │   ├── ClipboardMonitor.swift   # Polls NSPasteboard for changes
│   │   │   └── HotkeyManager.swift      # Global keyboard shortcuts
│   │   ├── Info.plist                   # macOS app config
│   │   └── ClipboardManager.entitlements # macOS permissions
│   │
│   ├── iOS/                             # iOS/iPadOS-specific
│   │   ├── ClipboardManageriOSApp.swift # iOS app entry point
│   │   ├── Views/
│   │   │   └── ClipboardListView.swift  # Main list, detail view, settings
│   │   ├── Services/
│   │   │   └── iOSClipboardHandler.swift # iOS clipboard + Shortcuts intents
│   │   ├── KeyboardExtension/           # Custom keyboard
│   │   │   ├── KeyboardViewController.swift
│   │   │   ├── Info.plist
│   │   │   └── ClipboardKeyboard.entitlements
│   │   ├── ShareExtension/              # Share sheet integration
│   │   │   ├── ShareViewController.swift
│   │   │   ├── Info.plist
│   │   │   └── ClipboardShare.entitlements
│   │   ├── WidgetExtension/             # Home/Lock screen widgets
│   │   │   ├── ClipboardWidget.swift
│   │   │   ├── Info.plist
│   │   │   └── ClipboardWidget.entitlements
│   │   ├── Info.plist                   # iOS app config
│   │   └── ClipboardManager.entitlements # iOS permissions
│   │
│   ├── project.yml                      # XcodeGen configuration
│   └── Makefile                         # Build automation
│
├── README.md                            # Project documentation
├── INSTALLATION_GUIDE.md                # 894-line detailed setup guide
├── LICENSE                              # MIT License
├── CLAUDE_CONTEXT.md                    # This file
└── .gitignore                           # Git ignore rules
```

---

## Key Identifiers

| Item | Value |
|------|-------|
| **macOS Bundle ID** | `com.hselbi.clipboardmanager` |
| **iOS Bundle ID** | `com.hselbi.clipboardmanager` |
| **Keyboard Bundle ID** | `com.hselbi.clipboardmanager.keyboard` |
| **Share Bundle ID** | `com.hselbi.clipboardmanager.share` |
| **Widget Bundle ID** | `com.hselbi.clipboardmanager.widget` |
| **App Group** | `group.com.hselbi.clipboardmanager` |
| **iCloud Container** | `iCloud.com.hselbi.clipboardmanager` |

---

## Technology Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 5.9 |
| UI Framework | SwiftUI |
| Data Persistence | SwiftData |
| Cloud Sync | CloudKit |
| Encryption | CryptoKit (AES-256-GCM) |
| Biometrics | LocalAuthentication |
| Project Generation | XcodeGen |
| Min macOS | 14.0 (Sonoma) |
| Min iOS | 17.0 |

---

## Features Implemented

### Core Features
- [x] Clipboard history storage (SwiftData)
- [x] iCloud sync across devices (CloudKit)
- [x] Fuzzy search
- [x] Pin items
- [x] Multiple content types (text, images, URLs, files)
- [x] Duplicate detection (consecutive + global)

### macOS Features
- [x] Menu bar app (NSStatusItem)
- [x] Global hotkey (⇧⌘V) via Carbon Events
- [x] Clipboard monitoring (NSPasteboard polling)
- [x] Auto-paste simulation (CGEvent)
- [x] Settings window (SwiftUI)

### iOS Features
- [x] Main app with list view
- [x] Keyboard extension
- [x] Share extension
- [x] Widget extension (small, medium, large, lock screen)
- [x] Siri Shortcuts integration (AppIntents)

### Security Features
- [x] Password manager detection (1Password, Bitwarden, etc.)
- [x] Sensitive content detection (credit cards, SSN, API keys)
- [x] AES-256-GCM encryption
- [x] Face ID / Touch ID support
- [x] Auto-delete sensitive items
- [x] Keychain storage for encryption keys

---

## Build Commands

```bash
# Navigate to project
cd /Users/selbihafid/Desktop/Maccy-copy/ClipboardManager

# Install XcodeGen (first time only)
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Open in Xcode
open ClipboardManager.xcodeproj

# Or use Makefile
make setup      # Install XcodeGen
make generate   # Generate project
make open       # Open Xcode
make build-macos      # Build macOS app
make build-ios        # Build iOS app (simulator)
make clean            # Clean build files
```

---

## Xcode Setup Steps

1. **Generate project**: `xcodegen generate`
2. **Open**: `open ClipboardManager.xcodeproj`
3. **Sign all targets** with your Apple Developer Team:
   - ClipboardManager-macOS
   - ClipboardManager-iOS
   - ClipboardKeyboard
   - ClipboardShare
   - ClipboardWidget
4. **Add capabilities**:
   - iCloud (CloudKit) - container: `iCloud.com.hselbi.clipboardmanager`
   - App Groups - group: `group.com.hselbi.clipboardmanager`
5. **Build and run**: ⌘R

---

## Files to Read for Full Understanding

If Claude needs to understand specific parts:

| Topic | File to Read |
|-------|--------------|
| Data model | `ClipboardManager/Shared/Models/ClipboardItem.swift` |
| Settings | `ClipboardManager/Shared/Models/AppSettings.swift` |
| Persistence | `ClipboardManager/Shared/Services/DataStore.swift` |
| Security | `ClipboardManager/Shared/Services/SecurityManager.swift` |
| macOS clipboard | `ClipboardManager/macOS/Services/ClipboardMonitor.swift` |
| macOS hotkeys | `ClipboardManager/macOS/Services/HotkeyManager.swift` |
| macOS UI | `ClipboardManager/macOS/Views/MenuBarView.swift` |
| macOS app | `ClipboardManager/macOS/ClipboardManagerApp.swift` |
| iOS clipboard | `ClipboardManager/iOS/Services/iOSClipboardHandler.swift` |
| iOS UI | `ClipboardManager/iOS/Views/ClipboardListView.swift` |
| iOS app | `ClipboardManager/iOS/ClipboardManageriOSApp.swift` |
| Keyboard | `ClipboardManager/iOS/KeyboardExtension/KeyboardViewController.swift` |
| Share ext | `ClipboardManager/iOS/ShareExtension/ShareViewController.swift` |
| Widget | `ClipboardManager/iOS/WidgetExtension/ClipboardWidget.swift` |
| XcodeGen | `ClipboardManager/project.yml` |
| Build | `ClipboardManager/Makefile` |
| Install guide | `INSTALLATION_GUIDE.md` |

---

## Common Tasks

### "I want to add a new feature"
1. Determine if it's shared, macOS-only, or iOS-only
2. Add code to appropriate folder
3. If new file, update `project.yml` sources
4. Run `xcodegen generate`
5. Build and test

### "I want to change the bundle ID"
1. Update `project.yml` - change all `com.hselbi.clipboardmanager` references
2. Update all `.entitlements` files
3. Update `AppSettings.swift` - appGroupIdentifier
4. Update `KeyboardViewController.swift` - appGroupIdentifier
5. Update `ShareViewController.swift` - appGroupIdentifier
6. Update `ClipboardWidget.swift` - appGroupIdentifier
7. Run `xcodegen generate`

### "App won't build"
1. Check Xcode → Preferences → Accounts (Apple ID signed in)
2. Check all targets have team selected
3. Check capabilities are properly configured
4. Try: `make clean` then rebuild

### "Sync not working"
1. Verify same Apple ID on all devices
2. Verify iCloud Drive enabled
3. Check app has iCloud capability
4. Check iCloud container name matches
5. Wait 1-2 minutes for initial sync

---

## GitHub Repository

**URL**: https://github.com/hselbi/ClipboardManager

**Commits**:
1. Initial commit - all source files
2. README, .gitignore, extensions
3. Complete implementation with assets
4. Makefile and build instructions
5. Comprehensive installation guide

---

## Owner

**GitHub**: hselbi
**Project started**: July 2024

---

## How to Use This File

In a new Claude conversation, say:

```
Read ~/Desktop/Maccy-copy/CLAUDE_CONTEXT.md and then help me with [your request]
```

Or:

```
Analyze my ClipboardManager project at ~/Desktop/Maccy-copy/
```

Claude will then read this file and understand the full project context.
