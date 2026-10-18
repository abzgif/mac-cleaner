import Foundation

/// Scans for residual support files, preferences, and caches from apps that have been uninstalled.
public final class AppLeftoversScanner: Scannable, Sendable {
    public let category: ScanCategory = .appLeftovers
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        // 1. Gather all installed applications (bundle IDs and App names)
        let installedApps = getInstalledAppsInfo()
        
        // 2. Scan directories where leftovers persist
        let searchDirectories: [URL] = [
            home.appendingPathComponent("Library/Application Support"),
            home.appendingPathComponent("Library/Saved Application State"),
            home.appendingPathComponent("Library/Preferences")
        ]
        
        for dir in searchDirectories {
            guard fileManager.fileExists(atPath: dir.path),
                  fileManager.isReadableFile(atPath: dir.path) else { continue }
            
            let contents = (try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            
            for itemURL in contents {
                if Task.isCancelled { break }
                let itemName = itemURL.lastPathComponent
                
                // Never touch Apple system files, system frameworks, or standard folders
                if isStandardAppleOrSystemFile(itemName) {
                    continue
                }
                
                // Check if this item belongs to any installed app
                if isAssociatedWithInstalledApp(itemName: itemName, installed: installedApps) {
                    continue
                }
                
                let size = ScannerHelper.size(of: itemURL)
                guard size > 1024 else { continue }
                
                let modDate = ScannerHelper.modificationDate(of: itemURL)
                let item = ScannedItem(
                    url: itemURL,
                    displayName: "Leftover: \(itemName)",
                    size: size,
                    category: category,
                    modificationDate: modDate,
                    isSelected: true,
                    parentAppName: itemName
                )
                results.append(item)
                onFoundItem?(item)
            }
        }
        
        return results
    }
    
    private struct InstalledInfo {
        var bundleIDs: Set<String>
        var appNames: Set<String>
    }
    
    private func getInstalledAppsInfo() -> InstalledInfo {
        var bundleIDs = Set<String>()
        var appNames = Set<String>()
        
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        
        let fileManager = FileManager.default
        for dir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
                continue
            }
            
            for appURL in contents where appURL.pathExtension == "app" {
                let name = appURL.deletingPathExtension().lastPathComponent.lowercased()
                appNames.insert(name)
                
                if let bundle = Bundle(url: appURL), let bundleID = bundle.bundleIdentifier {
                    bundleIDs.insert(bundleID.lowercased())
                }
            }
        }
        
        return InstalledInfo(bundleIDs: bundleIDs, appNames: appNames)
    }
    
    private func isStandardAppleOrSystemFile(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower.hasPrefix("com.apple.") ||
           lower.hasPrefix("apple") ||
           lower == "addressbook" ||
           lower == "dock" ||
           lower == "finder" ||
           lower == "systempreferences" ||
           lower == "safari" ||
           lower == "siri" ||
           lower == "icloud" ||
           lower == "syncservices" ||
           lower == "accounts" {
            return true
        }
        return false
    }
    
    private func isAssociatedWithInstalledApp(itemName: String, installed: InstalledInfo) -> Bool {
        let cleanName = itemName
            .replacingOccurrences(of: ".plist", with: "")
            .replacingOccurrences(of: ".savedState", with: "")
            .lowercased()
        
        // Exact bundle ID match
        if installed.bundleIDs.contains(cleanName) {
            return true
        }
        
        // App name match
        for appName in installed.appNames {
            if cleanName.contains(appName) || appName.contains(cleanName) {
                return true
            }
        }
        
        return false
    }
}
