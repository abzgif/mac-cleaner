### **Browse more useful projects at:** [bytegif.com](https://bytegif.com)

# CleanMac — Native macOS System Junk Cleaner
[![Release](https://img.shields.io/github/v/release/abzgif/mac-cleaner?color=blue)](https://github.com/abzgif/mac-cleaner/releases/latest)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat)](https://swift.org)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B%20(Sonoma)-blue.svg?style=flat)](https://apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**CleanMac** is a high-performance, native macOS application built with **Swift 6 + SwiftUI** targeting **macOS 14+ (Sonoma)**. Designed for distribution outside the Mac App Store, it provides transparent, privacy-first filesystem cleanup, developer artifact reclamation, duplicate file detection, and deep application uninstallation.

---

## 📥 Download (v1.1.0)

Download the latest version of CleanMac for macOS (Sonoma 14.0+):

- [**Download Latest Release on GitHub**](https://github.com/abzgif/mac-cleaner/releases/latest) (`CleanMac-1.1.0.dmg` & `CleanMac-1.1.0.zip`)

> **In-App Updates**: Already have CleanMac installed? Open **Settings & Protection → Software Update** inside the app and click **Check for Updates** to download, install, and relaunch the newest version automatically.

---

## ✨ What's New in v1.1.0

- **In-App Update Checker & Installer**: Check GitHub Releases directly from **Settings**, view release notes, and install new versions with a single click.
- **Streamlined Minimal 4-Tab UI**: Focused sidebar navigation (**Smart Clean**, **Applications**, **Storage Explorer**, and **Settings & Protection**) with real-time storage updates.
- **SDK & Developer Cache Cleanup**: Inspect and clean individual Android SDK components (`system-images`, `ndk`, `platforms`, `build-tools`, `AVDs`, temp caches), Gradle (`~/.gradle/caches`, `wrapper/dists`), Maven (`~/.m2/repository`), Xcode (`DerivedData`, `iOS DeviceSupport`, Simulator caches), and package manager caches (`Homebrew`, `NPM`, `Yarn`, `PNPM`, `Bun`, `Pip`, `UV`, `Cargo`, `Go`, `CocoaPods`, `SwiftPM`).
- **Multi-Select App Uninstaller**: Select multiple applications with checkboxes or `Select All` to batch-uninstall apps and clean their residual support, cache, and preference files.
- **Hardened App & IDE Safety**: Preserves `~/Library/Application Support`, `~/Library/Preferences`, `.app` bundle internals, JDownloader 2, and Android Studio IDE configurations during general scans.

---

## Key Features

### 1. Smart Clean
- **Application Caches**: Safely clears temporary caches in `~/Library/Caches` while protecting active apps, JDownloader 2, and IDE index/settings directories.
- **Browser Caches**: Reclaims cached web assets from closed browsers (Safari, Google Chrome, Firefox, Microsoft Edge, Arc, and Brave).
- **Logs & Crash Reports**: Cleans diagnostic logs and old crash reports.
- **Trash Bin**: Real-time inspection and 1-click emptying of `~/.Trash`.
- **SDKs & Developer Caches**: Lists individual Android SDK images/NDKs/platforms, Gradle/Maven caches, and package manager caches for on-demand developer cleanup.
- **Xcode & Simulator SDKs**: Deep clean for Xcode `DerivedData`, `iOS/watchOS DeviceSupport`, and simulator caches.
- **Old Installers (`.dmg` / `.pkg`)**: Identifies leftover installer disk images in `~/Downloads`.

### 2. Multi-Select App Uninstaller & Leftover Removal
- Recursively maps installed applications in `/Applications` and `~/Applications` (including subfolder installations).
- Supports checking single or multiple applications for batch uninstallation alongside their associated `Application Support`, `Caches`, `Preferences`, and `Saved Application State` files.

### 3. Unified Storage Explorer
- **Folder Sizes**: Visual folder drill-down with proportional size bars, Finder reveal, and direct move-to-Trash.
- **Large Files**: Identifies forgotten large files (`>50 MB`) while skipping active code repositories.
- **Duplicates**: Two-stage byte-size + **SHA-256** streaming hash duplicate detection.

### 4. Settings, Protection & In-App Updater
- **Software Update**: Checks GitHub Releases for new versions and installs updates directly from within the app.
- **Excluded Folders**: Custom folder exclusion list.
- **Cleanup History**: Audit log of recent cleanup sessions with 1-click **Restore from Trash**.

---

## Safety Architecture & Denylist Guarantees

CleanMac is engineered with a strict safety-first policy:

1. **Non-Destructive Deletions by Default**:
   - All deletions use `FileManager.default.trashItem(at:resultingItemURL:)` to move items to the user's macOS Trash bin.
   - Permanent deletion is an opt-in toggle in Settings with explicit confirmation.
2. **Hardcoded System Denylist**:
   - The application strictly enforces an immutable denylist protecting `/System`, `/bin`, `/sbin`, `/usr`, `/Library/Apple`, `/Library/Security`, and root filesystems.
   - Any path resolving inside these directories is instantly rejected by `SafetyPolicy`.
3. **Active Application Protection**:
   - Running applications and their active application support directories are detected via `NSWorkspace.shared.runningApplications` and excluded from scans and cleanups.
4. **User Essential Directories Protection**:
   - Critical user roots (`~`, `Desktop`, `Documents`, `Pictures`, `.ssh`, `Library/Keychains`) are permanently protected from deletion.
5. **Mandatory Review & Confirmation**:
   - No files are ever deleted without an explicit review dialog itemizing file counts, total bytes, affected categories, and confirmation.
6. **Audit Logs & Undo / Restore**:
   - Every cleanup session records an audit report stored in `Application Support/CleanMac/history.json`.
   - The History tab allows restoring trashed files within the session.

---

## Architecture Overview

CleanMac follows a clean MVVM architecture:

```
CleanMac/
├── Package.swift                    # Swift 6 Package definition
├── CleanMac.entitlements            # Hardened Runtime entitlements
├── Info.plist                       # Bundle metadata and privacy descriptions
├── scripts/
│   └── build_app.sh                 # App bundle packager and signing script
├── Sources/
│   ├── CleanMacApp/                 # Executable entry point with MenuBarExtra
│   │   └── CleanMacApp.swift
│   └── CleanMacCore/                # Modular framework target
│       ├── Models/                  # Value models (ScannedItem, ScanCategory, etc.)
│       ├── Services/                # Core engines, safety policy, and 11 scanners
│       ├── ViewModels/              # MVVM ViewModels with @Published & async tasks
│       ├── Views/                   # Native SwiftUI macOS views & components
│       └── Utilities/               # Byte formatting, streaming SHA-256, permissions
└── Tests/
    └── TestRunner/                  # Automated test runner suite
```

---

## Building and Running

### Prerequisites
- macOS 14.0 (Sonoma) or newer.
- Swift 6.0+ (via Xcode or Command Line Tools).

### 1. Build and Run via Swift Package Manager
```bash
# Build the project
swift build

# Run CleanMac directly
swift run CleanMac
```

### 2. Run Automated Test Suite
```bash
swift run CleanMacTestRunner
```
This executes the automated test suites verifying:
- `SafetyPolicy` denylist enforcement and traversal prevention.
- `CleanupEngine` Trash movement and exclusion protection.
- `DuplicateFinder` SHA-256 detection and selection strategies.
- `ByteFormatter` calculations.
- `ScanEngine` async streaming and cancellation.

### 3. Package `CleanMac.app` Bundle
To produce a standalone macOS `.app` bundle ready to drag into `/Applications`:
```bash
./scripts/build_app.sh
```
The packaged bundle will be generated at `build/CleanMac.app`.

---

## Code Signing & Developer ID Notarization

To distribute CleanMac outside the Mac App Store:

1. **Sign with Developer ID Application**:
   ```bash
   DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAM_ID)" ./scripts/build_app.sh
   ```

2. **Create Archive for Notarization**:
   ```bash
   ditto -c -k --keepParent "build/CleanMac.app" "build/CleanMac.zip"
   ```

3. **Submit to Apple Notary Service**:
   ```bash
   xcrun notarytool submit "build/CleanMac.zip" \
       --keychain-profile "AC_NOTARY_PROFILE" \
       --wait
   ```

4. **Staple Ticket to the App**:
   ```bash
   xcrun stapler staple "build/CleanMac.app"
   ```

---

## Permissions & Full Disk Access

Certain scan categories (such as user diagnostic logs in `~/Library/Logs` or Safari browser caches) require **Full Disk Access**.
CleanMac guides the user gracefully:
- When restricted directories are detected, an in-app banner provides a one-click button to open `System Settings > Privacy & Security > Full Disk Access`.
- Inaccessible files are logged and presented in a non-fatal access summary rather than terminating the scan.

---

## License

MIT License. Designed and built natively for macOS.
