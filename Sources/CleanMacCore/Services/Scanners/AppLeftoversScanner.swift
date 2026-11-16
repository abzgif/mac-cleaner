import Foundation

/// Scans ONLY for orphaned Saved Application State (.savedState) folders from uninstalled apps.
/// Never touches ~/Library/Application Support or ~/Library/Preferences automatically, preventing data loss in apps like JDownloader 2 and Android Studio.
public final class AppLeftoversScanner: Scannable, Sendable {
    public let category: ScanCategory = .appLeftovers
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        // 1. Gather all installed applications (including nested subfolders in /Applications and ~/Applications)
        let installedApps = Self.getInstalledAppsInfo()
        
        // 2. Only scan Saved Application State (window positions of uninstalled apps) — never Application Support or Preferences!
        let savedStateDir = home.appendingPathComponent("Library/Saved Application State")
        guard fileManager.fileExists(atPath: savedStateDir.path),
              fileManager.isReadableFile(atPath: savedStateDir.path) else {
            return results
        }
        
        let contents = (try? fileManager.contentsOfDirectory(
            at: savedStateDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        
        for itemURL in contents where itemURL.pathExtension == "savedState" {
            if Task.isCancelled { break }
            let itemName = itemURL.lastPathComponent
            
            if isStandardAppleOrProtectedFile(itemName) {
                continue
            }
            
            if SafetyPolicy.shared.isProtectedCacheOrAppPath(itemURL.path) {
                continue
            }
            
            if isAssociatedWithInstalledApp(itemName: itemName, installed: installedApps) {
                continue
            }
            
            let size = ScannerHelper.size(of: itemURL)
            guard size > 1024 * 10 else { continue }
            
            let modDate = ScannerHelper.modificationDate(of: itemURL)
            let item = ScannedItem(
                url: itemURL,
                displayName: itemName,
                size: size,
                category: category,
                modificationDate: modDate,
                isSelected: false,
                parentAppName: itemName.replacingOccurrences(of: ".savedState", with: "")
            )
            results.append(item)
            onFoundItem?(item)
        }
        
        return results.sorted { $0.size > $1.size }
    }
    
    public struct InstalledInfo: Sendable {
        public var bundleIDs: Set<String>
        public var appNames: Set<String>
    }
    
    /// Recursively discovers installed .app bundles up to 3 directory levels deep (e.g. /Applications/JDownloader 2/JDownloader2.app).
    public static func getInstalledAppsInfo() -> InstalledInfo {
        var bundleIDs = Set<String>()
        var appNames = Set<String>()
        
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        
        for dir in appDirs {
            collectApps(in: dir, currentDepth: 0, maxDepth: 3, bundleIDs: &bundleIDs, appNames: &appNames)
        }
        
        return InstalledInfo(bundleIDs: bundleIDs, appNames: appNames)
    }
    
    private static func collectApps(
        in dir: URL,
        currentDepth: Int,
        maxDepth: Int,
        bundleIDs: inout Set<String>,
        appNames: inout Set<String>
    ) {
        guard currentDepth <= maxDepth,
              let contents = try? FileManager.default.contentsOfDirectory(
                  at: dir,
                  includingPropertiesForKeys: [.isDirectoryKey],
                  options: [.skipsHiddenFiles]
              ) else {
            return
        }
        
        for url in contents {
            if url.pathExtension.lowercased() == "app" {
                let name = url.deletingPathExtension().lastPathComponent.lowercased()
                appNames.insert(name)
                if let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier {
                    bundleIDs.insert(bundleID.lowercased())
                }
            } else if currentDepth < maxDepth {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    // Also record parent folder name in /Applications (e.g., "JDownloader 2")
                    appNames.insert(url.lastPathComponent.lowercased())
                    collectApps(in: url, currentDepth: currentDepth + 1, maxDepth: maxDepth, bundleIDs: &bundleIDs, appNames: &appNames)
                }
            }
        }
    }
    
    private func isStandardAppleOrProtectedFile(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasPrefix("com.apple.") ||
               lower.hasPrefix("apple") ||
               lower.contains("jdownloader") ||
               lower.contains("install4j") ||
               lower.contains("android") ||
               lower.contains("jetbrains") ||
               lower.contains("google")
    }
    
    private func isAssociatedWithInstalledApp(itemName: String, installed: InstalledInfo) -> Bool {
        let cleanName = itemName
            .replacingOccurrences(of: ".plist", with: "")
            .replacingOccurrences(of: ".savedState", with: "")
            .lowercased()
        
        if installed.bundleIDs.contains(cleanName) {
            return true
        }
        
        for appName in installed.appNames where appName.count >= 3 {
            if cleanName.contains(appName) || appName.contains(cleanName) {
                return true
            }
        }
        
        return false
    }
}
