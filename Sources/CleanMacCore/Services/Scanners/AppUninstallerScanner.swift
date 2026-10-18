import Foundation
import AppKit

/// Scans installed macOS applications and detects all associated caches, preferences, and container directories.
public final class AppUninstallerScanner: Sendable {
    
    public init() {}
    
    public func scanInstalledApps(
        onFoundApp: (@Sendable (AppItem) -> Void)? = nil
    ) async -> [AppItem] {
        var appItems: [AppItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        let appDirectories = [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications")
        ]
        
        for dir in appDirectories {
            guard fileManager.fileExists(atPath: dir.path),
                  fileManager.isReadableFile(atPath: dir.path) else { continue }
            
            let contents = (try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            
            for appURL in contents where appURL.pathExtension == "app" {
                if Task.isCancelled { break }
                
                let appName = appURL.deletingPathExtension().lastPathComponent
                let bundle = Bundle(url: appURL)
                let bundleID = bundle?.bundleIdentifier
                
                // Identify system apps
                let isSystem = appURL.path.hasPrefix("/System") ||
                               bundleID?.hasPrefix("com.apple.") == true
                
                let appSize = ScannerHelper.size(of: appURL)
                let modDate = ScannerHelper.modificationDate(of: appURL)
                let relatedItems = findRelatedFiles(for: appName, bundleID: bundleID, home: home)
                
                let item = AppItem(
                    bundleIdentifier: bundleID,
                    name: appName,
                    bundleURL: appURL,
                    appSize: appSize,
                    relatedItems: relatedItems,
                    isSelected: false,
                    isSystemApp: isSystem,
                    modificationDate: modDate
                )
                
                appItems.append(item)
                onFoundApp?(item)
            }
        }
        
        // Sort by total size descending
        return appItems.sorted { $0.totalSize > $1.totalSize }
    }
    
    private func findRelatedFiles(for appName: String, bundleID: String?, home: URL) -> [ScannedItem] {
        var related: [ScannedItem] = []
        let fileManager = FileManager.default
        let appNameLower = appName.lowercased()
        let bundleIDLower = bundleID?.lowercased()
        
        let candidatePaths: [(category: ScanCategory, base: URL)] = [
            (.appLeftovers, home.appendingPathComponent("Library/Application Support")),
            (.systemCaches, home.appendingPathComponent("Library/Caches")),
            (.appLeftovers, home.appendingPathComponent("Library/Preferences")),
            (.appLeftovers, home.appendingPathComponent("Library/Saved Application State")),
            (.appLeftovers, home.appendingPathComponent("Library/Containers"))
        ]
        
        for (category, baseDir) in candidatePaths {
            guard fileManager.fileExists(atPath: baseDir.path),
                  fileManager.isReadableFile(atPath: baseDir.path) else { continue }
            
            let files = (try? fileManager.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil)) ?? []
            
            for fileURL in files {
                let filename = fileURL.lastPathComponent.lowercased()
                var isMatch = false
                
                if let bID = bundleIDLower, filename.contains(bID) {
                    isMatch = true
                } else if filename.contains(appNameLower) {
                    isMatch = true
                }
                
                if isMatch {
                    let size = ScannerHelper.size(of: fileURL)
                    let modDate = ScannerHelper.modificationDate(of: fileURL)
                    related.append(
                        ScannedItem(
                            url: fileURL,
                            displayName: fileURL.lastPathComponent,
                            size: size,
                            category: category,
                            modificationDate: modDate,
                            isSelected: true,
                            parentAppName: appName
                        )
                    )
                }
            }
        }
        
        return related
    }
}
