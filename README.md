# CleanMac — Native macOS System Junk Cleaner

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat)](https://swift.org)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B%20(Sonoma)-blue.svg?style=flat)](https://apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**CleanMac** is a high-performance, native macOS application built with **Swift 6 + SwiftUI** targeting **macOS 14+ (Sonoma)**. Designed for distribution outside the Mac App Store, it provides transparent, privacy-first filesystem cleanup, developer artifact reclamation, duplicate file detection, and deep application uninstallation.

---

## Key Features

### 1. Smart Scan
- **System & User Caches**: Safely clears accumulated temporary caches in `~/Library/Caches` and `/Library/Caches`.
- **User Logs & Crash Reports**: Cleans diagnostic logs, crash reports, and system log archives.
- **App Leftovers**: Discovers residual preferences, support folders, and caches left behind by uninstalled applications.
- **Browser Caches**: Reclaims cached web assets from Safari, Google Chrome, Firefox, Microsoft Edge, Arc, and Brave.
- **Xcode Developer Junk**: Deep clean for developers — DerivedData, Archives, iOS DeviceSupport, and simulator caches.
- **Downloads Folder**: Identifies old files and leftover `.dmg`, `.pkg`, and `.iso` disk images past a configurable age threshold.
- **System Trash**: Real-time inspection and 1-click emptying of `~/.Trash`.
- **Unused Language Files**: Advanced detection of unused `.lproj` localization bundles in third-party applications (opt-in with clear safety warnings).

### 2. Large & Old Files Finder
- Identifies forgotten large files (>50MB, >100MB, >500MB, >1GB) not modified in 30, 60, 90, or 365 days.
- Sortable by size, last modification date, and filename.
- Contextual Finder reveal integration for manual inspection before deletion.

### 3. Cryptographic Duplicate Finder
- Two-stage detection: clusters candidates by byte size first, then computes **SHA-256** streaming hashes to identify exact duplicates.
- Auto-selection strategies: "Keep Oldest", "Keep Newest", or manual selection.

### 4. App Uninstaller & Leftover Removal
- Maps all installed applications in `/Applications` and `~/Applications`.
- Discovers associated application support files, caches, preferences, and saved states.
- Allows complete uninstallation of both the `.app` bundle and its residual files.
- Protects macOS system applications from accidental modification.

### 5. Native Dashboard & Menu Bar Extra
- Real-time circular storage gauge (Used vs. Free space).
- Historical cleanup trend vector sparkline.
- Menu Bar Extra for a quick storage glance and 1-click quick cleanup.

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
