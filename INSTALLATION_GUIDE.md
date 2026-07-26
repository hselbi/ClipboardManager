# ClipboardManager - Complete Installation Guide

## Table of Contents
1. [Prerequisites](#1-prerequisites)
2. [Project Overview](#2-project-overview)
3. [Generate Xcode Project](#3-generate-xcode-project)
4. [Xcode Configuration](#4-xcode-configuration)
5. [Code Signing Setup](#5-code-signing-setup)
6. [iCloud & CloudKit Setup](#6-icloud--cloudkit-setup)
7. [App Groups Setup](#7-app-groups-setup)
8. [Build for macOS](#8-build-for-macos)
9. [Build for iOS/iPadOS](#9-build-for-iosipados)
10. [Install on Devices](#10-install-on-devices)
11. [Enable Keyboard Extension](#11-enable-keyboard-extension)
12. [Enable Widget](#12-enable-widget)
13. [Configure iCloud Sync](#13-configure-icloud-sync)
14. [Testing Sync](#14-testing-sync)
15. [Troubleshooting](#15-troubleshooting)
16. [Maintenance](#16-maintenance)

---

## 1. Prerequisites

### 1.1 Hardware Requirements
- **Mac** with macOS 14.0 (Sonoma) or later
- **iPhone** with iOS 17.0 or later (optional)
- **iPad** with iPadOS 17.0 or later (optional)
- **USB-C or Lightning cable** to connect iOS devices

### 1.2 Software Requirements
- **Xcode 15.0+** - Download from Mac App Store
- **Homebrew** - Package manager for macOS
- **XcodeGen** - Generates Xcode projects (installed via Homebrew)
- **Git** - Version control (pre-installed on macOS)

### 1.3 Apple Developer Account
| Account Type | Cost | App Validity | TestFlight | App Store |
|--------------|------|--------------|------------|-----------|
| Free | $0 | 7 days | No | No |
| Paid | $99/year | 1 year | Yes | Yes |

**To create Apple Developer Account:**
1. Go to https://developer.apple.com
2. Sign in with your Apple ID
3. Accept the developer agreement
4. (Optional) Enroll in the paid program for $99/year

### 1.4 iCloud Requirements
- All devices must be signed into the **same Apple ID**
- **iCloud Drive** must be enabled on all devices
- Sufficient iCloud storage (app uses minimal space)

### 1.5 Install Homebrew (if not installed)
Open Terminal and run:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 1.6 Install XcodeGen
```bash
brew install xcodegen
```

Verify installation:
```bash
xcodegen --version
# Should output: Version: 2.x.x
```

---

## 2. Project Overview

### 2.1 Project Location
```
/Users/selbihafid/Desktop/Maccy-copy/
├── ClipboardManager/          # Main project folder
│   ├── Shared/                # Shared code (macOS + iOS)
│   ├── macOS/                 # macOS-specific code
│   ├── iOS/                   # iOS-specific code
│   ├── project.yml            # XcodeGen configuration
│   └── Makefile               # Build automation
├── README.md                  # Project documentation
├── LICENSE                    # MIT License
└── .gitignore                 # Git ignore rules
```

### 2.2 Targets Overview
| Target | Platform | Bundle ID | Description |
|--------|----------|-----------|-------------|
| ClipboardManager-macOS | macOS 14.0+ | com.hselbi.clipboardmanager | Menu bar app |
| ClipboardManager-iOS | iOS 17.0+ | com.hselbi.clipboardmanager | Main iOS app |
| ClipboardKeyboard | iOS 17.0+ | com.hselbi.clipboardmanager.keyboard | Keyboard extension |
| ClipboardShare | iOS 17.0+ | com.hselbi.clipboardmanager.share | Share extension |
| ClipboardWidget | iOS 17.0+ | com.hselbi.clipboardmanager.widget | Home screen widget |

### 2.3 Bundle ID Structure
```
com.hselbi.clipboardmanager                    # Main app
com.hselbi.clipboardmanager.keyboard           # Keyboard extension
com.hselbi.clipboardmanager.share              # Share extension
com.hselbi.clipboardmanager.widget             # Widget extension
```

**IMPORTANT**: You may need to change `hselbi` to your own unique identifier if there are conflicts.

### 2.4 App Group Identifier
```
group.com.hselbi.clipboardmanager
```
This allows the main app and extensions to share data.

### 2.5 iCloud Container Identifier
```
iCloud.com.hselbi.clipboardmanager
```
This stores synced clipboard data in iCloud.

---

## 3. Generate Xcode Project

### 3.1 Navigate to Project Directory
```bash
cd /Users/selbihafid/Desktop/Maccy-copy/ClipboardManager
```

### 3.2 Verify project.yml Exists
```bash
ls -la project.yml
# Should show: -rw-r--r-- ... project.yml
```

### 3.3 Generate Xcode Project
```bash
xcodegen generate
```

**Expected Output:**
```
⚙️  Generating plists...
⚙️  Generating project...
⚙️  Writing project...
Created project at /Users/selbihafid/Desktop/Maccy-copy/ClipboardManager/ClipboardManager.xcodeproj
```

### 3.4 Verify Project Created
```bash
ls -la ClipboardManager.xcodeproj
# Should show the .xcodeproj directory
```

### 3.5 Open in Xcode
```bash
open ClipboardManager.xcodeproj
```

Or use the Makefile:
```bash
make open
```

---

## 4. Xcode Configuration

### 4.1 Xcode Interface Overview
When you open the project, you'll see:
```
┌─────────────────────────────────────────────────────────────┐
│ Navigator │        Editor Area           │   Inspector     │
│ (Left)    │        (Center)              │   (Right)       │
│           │                              │                 │
│ 📁 Project│   Code / Settings View       │   Properties    │
│   ├─Shared│                              │                 │
│   ├─macOS │                              │                 │
│   ├─iOS   │                              │                 │
│           │                              │                 │
└─────────────────────────────────────────────────────────────┘
│                    Toolbar (Top)                            │
│  [Run] [Stop] [Scheme: ...] [Device: ...]                  │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Select Project in Navigator
1. Click on **ClipboardManager** (blue icon) in the left sidebar
2. This opens project settings in the center panel

### 4.3 View All Targets
In the center panel, you'll see:
- **PROJECT**: ClipboardManager
- **TARGETS**:
  - ClipboardManager-macOS
  - ClipboardManager-iOS
  - ClipboardKeyboard
  - ClipboardShare
  - ClipboardWidget

---

## 5. Code Signing Setup

### 5.1 Configure macOS Target

1. **Select Target**: Click `ClipboardManager-macOS` under TARGETS
2. **Select Tab**: Click `Signing & Capabilities` tab
3. **Enable Automatic Signing**: Check ✓ "Automatically manage signing"
4. **Select Team**:
   - Click the Team dropdown
   - Select your Apple ID / Developer Team
   - If not listed, click "Add Account..." and sign in

**Settings should show:**
```
┌─────────────────────────────────────────┐
│ Signing & Capabilities                  │
├─────────────────────────────────────────┤
│ ✓ Automatically manage signing          │
│                                         │
│ Team: Your Name (Personal Team)         │
│       or                                │
│       Your Company (XXXXXXXXXX)         │
│                                         │
│ Bundle Identifier: com.hselbi.clipboard │
│                    manager              │
│                                         │
│ Signing Certificate: Apple Development  │
│                                         │
│ Provisioning Profile: Xcode Managed     │
│                       Profile           │
└─────────────────────────────────────────┘
```

### 5.2 Configure iOS Target

1. **Select Target**: Click `ClipboardManager-iOS` under TARGETS
2. **Select Tab**: Click `Signing & Capabilities` tab
3. **Enable Automatic Signing**: Check ✓ "Automatically manage signing"
4. **Select Team**: Same team as macOS

### 5.3 Configure Keyboard Extension

1. **Select Target**: Click `ClipboardKeyboard` under TARGETS
2. **Select Tab**: Click `Signing & Capabilities` tab
3. **Enable Automatic Signing**: Check ✓ "Automatically manage signing"
4. **Select Team**: Same team as main app

### 5.4 Configure Share Extension

1. **Select Target**: Click `ClipboardShare` under TARGETS
2. **Select Tab**: Click `Signing & Capabilities` tab
3. **Enable Automatic Signing**: Check ✓ "Automatically manage signing"
4. **Select Team**: Same team as main app

### 5.5 Configure Widget Extension

1. **Select Target**: Click `ClipboardWidget` under TARGETS
2. **Select Tab**: Click `Signing & Capabilities` tab
3. **Enable Automatic Signing**: Check ✓ "Automatically manage signing"
4. **Select Team**: Same team as main app

### 5.6 Signing Summary
| Target | Team | Bundle ID |
|--------|------|-----------|
| ClipboardManager-macOS | Your Team | com.hselbi.clipboardmanager |
| ClipboardManager-iOS | Your Team | com.hselbi.clipboardmanager |
| ClipboardKeyboard | Your Team | com.hselbi.clipboardmanager.keyboard |
| ClipboardShare | Your Team | com.hselbi.clipboardmanager.share |
| ClipboardWidget | Your Team | com.hselbi.clipboardmanager.widget |

---

## 6. iCloud & CloudKit Setup

### 6.1 Add iCloud Capability to macOS Target

1. **Select Target**: `ClipboardManager-macOS`
2. **Select Tab**: `Signing & Capabilities`
3. **Add Capability**: Click `+ Capability` button (top left of capabilities area)
4. **Search**: Type "iCloud" in the search box
5. **Select**: Double-click "iCloud"

### 6.2 Configure iCloud for macOS

After adding, configure:
```
┌─────────────────────────────────────────┐
│ iCloud                              [-] │
├─────────────────────────────────────────┤
│ Services:                               │
│   ☐ Key-value storage                   │
│   ✓ CloudKit                            │
│   ☐ iCloud Documents                    │
│                                         │
│ Containers:                             │
│   ┌─────────────────────────────────┐   │
│   │ iCloud.com.hselbi.clipboardmgr  │   │
│   └─────────────────────────────────┘   │
│   [+] [-] [Refresh]                     │
└─────────────────────────────────────────┘
```

**Steps:**
1. Check ✓ **CloudKit**
2. Under Containers, click **+** button
3. Enter: `iCloud.com.hselbi.clipboardmanager`
4. Click OK
5. Make sure your new container is checked ✓

### 6.3 Add iCloud Capability to iOS Target

1. **Select Target**: `ClipboardManager-iOS`
2. **Select Tab**: `Signing & Capabilities`
3. **Add Capability**: Click `+ Capability`
4. **Add**: "iCloud"
5. **Configure**: Same as macOS (CloudKit, same container)

### 6.4 Verify iCloud Container

Both macOS and iOS targets must use the **same** iCloud container:
```
iCloud.com.hselbi.clipboardmanager
```

---

## 7. App Groups Setup

App Groups allow the main app and extensions to share data.

### 7.1 Add App Groups to iOS Target

1. **Select Target**: `ClipboardManager-iOS`
2. **Select Tab**: `Signing & Capabilities`
3. **Add Capability**: Click `+ Capability`
4. **Add**: "App Groups"

### 7.2 Configure App Group

```
┌─────────────────────────────────────────┐
│ App Groups                          [-] │
├─────────────────────────────────────────┤
│ ✓ group.com.hselbi.clipboardmanager     │
│                                         │
│ [+] [-] [Refresh]                       │
└─────────────────────────────────────────┘
```

**Steps:**
1. Click **+** button
2. Enter: `group.com.hselbi.clipboardmanager`
3. Click OK
4. Ensure it's checked ✓

### 7.3 Add App Groups to All Extensions

Repeat for each extension target:
- **ClipboardKeyboard**
- **ClipboardShare**
- **ClipboardWidget**

**For each:**
1. Select the target
2. Go to `Signing & Capabilities`
3. Add "App Groups" capability
4. Select the **same** group: `group.com.hselbi.clipboardmanager`

### 7.4 Verify App Groups

All iOS targets must have the same App Group:
| Target | App Group |
|--------|-----------|
| ClipboardManager-iOS | group.com.hselbi.clipboardmanager ✓ |
| ClipboardKeyboard | group.com.hselbi.clipboardmanager ✓ |
| ClipboardShare | group.com.hselbi.clipboardmanager ✓ |
| ClipboardWidget | group.com.hselbi.clipboardmanager ✓ |

---

## 8. Build for macOS

### 8.1 Select Scheme and Destination

1. **Scheme**: Click the scheme selector in toolbar
   - Select: `ClipboardManager-macOS`
2. **Destination**: Click the destination selector
   - Select: `My Mac`

```
┌────────────────────────────────────────────────────┐
│ [▶] [■] │ ClipboardManager-macOS ▼ │ My Mac ▼    │
└────────────────────────────────────────────────────┘
```

### 8.2 Build the App

**Method 1: Keyboard Shortcut**
- Press `⌘B` to build
- Press `⌘R` to build and run

**Method 2: Menu**
- Product → Build (⌘B)
- Product → Run (⌘R)

**Method 3: Makefile**
```bash
cd /Users/selbihafid/Desktop/Maccy-copy/ClipboardManager
make build-macos
```

### 8.3 Build Output

Successful build shows:
```
Build Succeeded
```

The app appears in your menu bar with a clipboard icon.

### 8.4 App Location

Debug build location:
```
~/Library/Developer/Xcode/DerivedData/ClipboardManager-xxx/Build/Products/Debug/ClipboardManager.app
```

### 8.5 Install to Applications

To install permanently:
```bash
# Find the built app
BUILD_DIR=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipboardManager.app" -path "*/Debug/*" | head -1)

# Copy to Applications
cp -r "$BUILD_DIR" /Applications/ClipboardManager.app

# Verify
ls -la /Applications/ClipboardManager.app
```

### 8.6 Launch at Login (Optional)

1. Open **System Settings** → **General** → **Login Items**
2. Click **+** under "Open at Login"
3. Navigate to `/Applications/ClipboardManager.app`
4. Click **Open**

---

## 9. Build for iOS/iPadOS

### 9.1 Connect Your Device

1. **Connect** iPhone/iPad to Mac using USB cable
2. **Unlock** your device
3. **Trust** the computer if prompted on device

### 9.2 Select Scheme and Destination

1. **Scheme**: `ClipboardManager-iOS`
2. **Destination**: Your device name (e.g., "John's iPhone")

```
┌──────────────────────────────────────────────────────────┐
│ [▶] [■] │ ClipboardManager-iOS ▼ │ John's iPhone ▼     │
└──────────────────────────────────────────────────────────┘
```

### 9.3 First Time Setup

If this is first time deploying to device:

1. **Xcode** may show: "Device not registered"
2. Click **Register Device**
3. Xcode registers device with Apple Developer

### 9.4 Build and Run

Press `⌘R` or click the Play button.

**First build takes longer** as it:
1. Compiles all code
2. Creates provisioning profiles
3. Signs the app
4. Installs on device

### 9.5 Trust Developer Certificate (First Time)

On your iPhone/iPad:

1. Open **Settings**
2. Go to **General**
3. Scroll to **VPN & Device Management**
4. Under "DEVELOPER APP", tap your developer certificate
5. Tap **Trust "Apple Development: your@email.com"**
6. Tap **Trust** to confirm

### 9.6 Build for iPad

Same process as iPhone:
1. Connect iPad
2. Select iPad as destination
3. Build and run (⌘R)
4. Trust certificate if needed

---

## 10. Install on Devices

### 10.1 Installation Summary

| Device | Method | Validity |
|--------|--------|----------|
| Mac | Build from Xcode, copy to /Applications | Permanent |
| iPhone | Build from Xcode via USB | 7 days (free) / 1 year (paid) |
| iPad | Build from Xcode via USB | 7 days (free) / 1 year (paid) |

### 10.2 Using TestFlight (Paid Account Only)

For longer validity and wireless installs:

1. **Archive the App**
   - In Xcode: Product → Archive
   - Wait for archive to complete

2. **Distribute via TestFlight**
   - In Archives window, click "Distribute App"
   - Select "TestFlight & App Store"
   - Follow prompts to upload

3. **Install via TestFlight**
   - On iPhone/iPad, install TestFlight from App Store
   - Open TestFlight
   - Accept invitation to test
   - Install ClipboardManager

### 10.3 Re-installing (Free Account)

When app expires after 7 days:

1. Connect device to Mac
2. Open Xcode project
3. Build and run again (⌘R)

---

## 11. Enable Keyboard Extension

The keyboard extension lets you access clipboard history from any app.

### 11.1 On iPhone/iPad

1. Open **Settings**
2. Go to **General**
3. Tap **Keyboard**
4. Tap **Keyboards**
5. Tap **Add New Keyboard...**
6. Under "THIRD-PARTY KEYBOARDS", tap **ClipboardKeyboard**

### 11.2 Enable Full Access

For clipboard access to work:

1. In **Settings → General → Keyboard → Keyboards**
2. Tap **ClipboardKeyboard**
3. Enable **Allow Full Access**
4. Tap **Allow** when prompted

```
┌─────────────────────────────────────────┐
│ ClipboardKeyboard                       │
├─────────────────────────────────────────┤
│ Allow Full Access              [====●] │
│                                         │
│ Full Access allows the developer to     │
│ transmit anything you type...           │
└─────────────────────────────────────────┘
```

### 11.3 Using the Keyboard

1. Open any app with text input (Notes, Messages, etc.)
2. Tap the text field to show keyboard
3. Tap and hold the 🌐 globe icon
4. Select **ClipboardKeyboard**
5. Your clipboard history appears

---

## 12. Enable Widget

### 12.1 Add Widget to Home Screen (iPhone/iPad)

1. **Long press** on home screen until icons jiggle
2. Tap **+** button (top left corner)
3. Search for **ClipboardManager** or **Clipboard**
4. Select widget size (Small, Medium, or Large)
5. Tap **Add Widget**
6. Position widget and tap **Done**

### 12.2 Widget Sizes

| Size | Shows |
|------|-------|
| Small | Latest clipboard item |
| Medium | 3 recent items |
| Large | 5 recent items with details |

### 12.3 Lock Screen Widget (iOS 16+)

1. Long press on Lock Screen
2. Tap **Customize**
3. Select Lock Screen
4. Tap widget area
5. Add ClipboardManager widget

---

## 13. Configure iCloud Sync

### 13.1 On Mac

1. Click the **clipboard icon** in menu bar
2. Click **gear icon** (Settings)
3. Or press **⌘,** while app is focused
4. Go to **General** tab
5. Enable **iCloud Sync** toggle

### 13.2 On iPhone/iPad

1. Open **ClipboardManager** app
2. Tap **Settings** (gear icon)
3. Enable **iCloud Sync** toggle

### 13.3 Verify iCloud is Working

**Check iCloud Settings:**

On Mac:
1. System Settings → Apple ID → iCloud
2. Verify iCloud Drive is ON
3. Check that ClipboardManager is listed

On iPhone/iPad:
1. Settings → Apple ID → iCloud
2. Verify iCloud Drive is ON
3. Check under "Apps Using iCloud"

### 13.4 Sync Timing

- **Near-instant**: Changes sync within seconds
- **Background**: iOS may delay syncs to save battery
- **First sync**: May take 1-2 minutes for initial data

---

## 14. Testing Sync

### 14.1 Test Mac → iPhone

1. **On Mac**: Copy some text (⌘C)
2. **On Mac**: Open ClipboardManager from menu bar
3. **Verify**: Item appears in history
4. **On iPhone**: Open ClipboardManager app
5. **Verify**: Same item appears (may take a few seconds)

### 14.2 Test iPhone → Mac

1. **On iPhone**: Copy text from any app
2. **On iPhone**: Open ClipboardManager
3. **Tap**: "Capture Clipboard" or pull to refresh
4. **Verify**: Item appears in history
5. **On Mac**: Open ClipboardManager from menu bar
6. **Verify**: Same item appears

### 14.3 Test Pin Sync

1. **On Mac**: Pin an item (click pin icon)
2. **On iPhone**: Verify item shows as pinned
3. **On iPhone**: Unpin the item
4. **On Mac**: Verify item is unpinned

### 14.4 Troubleshooting Sync

If sync doesn't work:

1. **Check same Apple ID** on all devices
2. **Check iCloud Drive** is enabled
3. **Check internet connection**
4. **Force refresh**: Kill and reopen app
5. **Check CloudKit Dashboard** (for paid accounts):
   - Go to https://icloud.developer.apple.com
   - Check your container for data

---

## 15. Troubleshooting

### 15.1 Build Errors

**Error: "No account for team"**
```
Solution: Xcode → Preferences → Accounts → Add Apple ID
```

**Error: "Provisioning profile doesn't include..."**
```
Solution:
1. Select target
2. Uncheck "Automatically manage signing"
3. Check it again
4. Let Xcode regenerate profiles
```

**Error: "Device not registered"**
```
Solution: Click "Register Device" when prompted
```

### 15.2 Runtime Errors

**App crashes on launch:**
```
Solution:
1. Check Console app for crash logs
2. In Xcode: Window → Devices and Simulators
3. Select device → View Device Logs
```

**Keyboard not showing:**
```
Solution:
1. Settings → General → Keyboard → Keyboards
2. Delete and re-add ClipboardKeyboard
3. Re-enable Full Access
```

### 15.3 Sync Issues

**Items not syncing:**
```
Solution:
1. Check iCloud is signed in
2. Check iCloud Drive is enabled
3. Check network connection
4. Wait 1-2 minutes
5. Kill and reopen app
```

**Duplicate items:**
```
Solution:
1. Clear history on one device
2. Wait for sync
3. This is a known CloudKit merge behavior
```

### 15.4 Certificate Issues

**"Untrusted Developer" on iPhone:**
```
Solution:
Settings → General → VPN & Device Management → Trust certificate
```

**Certificate expired:**
```
Solution:
Rebuild and reinstall from Xcode
```

### 15.5 macOS Specific

**App not in menu bar:**
```
Solution:
1. Check System Settings → Control Center → Menu Bar Only
2. Look for clipboard icon
3. May be hidden if menu bar is full
```

**Accessibility permission denied:**
```
Solution:
1. System Settings → Privacy & Security → Accessibility
2. Add ClipboardManager
3. Enable toggle
```

---

## 16. Maintenance

### 16.1 Updating the App

When you make code changes:

```bash
cd /Users/selbihafid/Desktop/Maccy-copy/ClipboardManager

# Pull latest changes (if using git)
git pull

# Regenerate project if project.yml changed
xcodegen generate

# Open and build
open ClipboardManager.xcodeproj
```

Then build and run for each platform.

### 16.2 Renewing Certificates

**Free Account:**
- Rebuild every 7 days

**Paid Account:**
- Certificates auto-renew in Xcode
- Check Xcode → Preferences → Accounts → Manage Certificates

### 16.3 Backing Up Data

iCloud data is automatically backed up. For local backup:

```bash
# macOS data location
~/Library/Containers/com.hselbi.clipboardmanager/

# Back up
cp -r ~/Library/Containers/com.hselbi.clipboardmanager/ ~/Desktop/ClipboardManager-Backup/
```

### 16.4 Cleaning Up

```bash
cd /Users/selbihafid/Desktop/Maccy-copy/ClipboardManager

# Clean build files
make clean

# Remove derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/ClipboardManager-*
```

---

## Quick Reference Card

### Keyboard Shortcuts (macOS App)
| Shortcut | Action |
|----------|--------|
| ⇧⌘V | Open clipboard history |
| ↵ | Paste selected item |
| ⌥↵ | Paste without formatting |
| ⌥P | Toggle pin |
| ⌥⌫ | Delete item |
| ⌘1-9 | Quick paste pinned items |
| ↑↓ | Navigate |
| ⎋ | Close |

### File Locations
| Item | Location |
|------|----------|
| Project | `/Users/selbihafid/Desktop/Maccy-copy/ClipboardManager/` |
| Xcode Project | `ClipboardManager.xcodeproj` |
| macOS App | `/Applications/ClipboardManager.app` |
| macOS Data | `~/Library/Containers/com.hselbi.clipboardmanager/` |

### Important Identifiers
| Item | Value |
|------|-------|
| Bundle ID | com.hselbi.clipboardmanager |
| App Group | group.com.hselbi.clipboardmanager |
| iCloud Container | iCloud.com.hselbi.clipboardmanager |
| Team | Your Apple Developer Team |

---

## Need Help?

If you encounter issues not covered here:

1. **Check Xcode Console** for error messages
2. **Check device Console** (on Mac: Applications → Utilities → Console)
3. **Search error message** on Apple Developer Forums
4. **Open an issue** on GitHub repository

---

*Last updated: 2024*
*ClipboardManager v1.0.0*
