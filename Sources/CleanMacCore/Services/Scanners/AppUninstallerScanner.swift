import Foundation
import AppKit

/// Scans installed macOS applications (including subfolder installations like JDownloader 2) and detects their associated caches, preferences, and support directories for explicit uninstallation.
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
        
        var discoveredAppURLs: [URL] = []
        for dir in appDirectories {
            collectAppBundles(in: dir, currentDepth: 0, maxDepth: 2, result: &discoveredAppURLs)
        }
        
        for appURL in discoveredAppURLs {
            if Task.isCancelled { break }
            
            let appName = appURL.deletingPathExtension().lastPathComponent
            let bundle = Bundle(url: appURL)
            let bundleID = bundle?.bundleIdentifier
            
            // Skip Apple system apps and CleanMac itself
            let isSystem = appURL.path.hasPrefix("/System") ||
                           bundleID?.hasPrefix("com.apple.") == true ||
                           bundleID == "com.cleanmac.app"
            
            guard fileManager.fileExists(atPath: appURL.path) else { continue }
            
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
        
        return appItems.sorted { $0.totalSize > $1.totalSize }
    }
    
    private func collectAppBundles(in directory: URL, currentDepth: Int, maxDepth: Int, result: inout [URL]) {
        guard currentDepth <= maxDepth else { return }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path),
              fileManager.isReadableFile(atPath: directory.path),
              let contents = try? fileManager.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: [.isDirectoryKey],
                  options: [.skipsHiddenFiles]
              ) else {
            return
        }
        
        for url in contents {
            if url.pathExtension.lowercased() == "app" {
                result.append(url)
            } else if currentDepth < maxDepth {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    collectAppBundles(in: url, currentDepth: currentDepth + 1, maxDepth: maxDepth, result: &result)
                }
            }
        }
    }
    
    private func findRelatedFiles(for appName: String, bundleID: String?, home: URL) -> [ScannedItem] {
        var related: [ScannedItem] = []
        let fileManager = FileManager.default
        let appNameNormalized = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleIDLower = bundleID?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
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
            
            let files = (try? fileManager.contentsOfDirectory(
                at: baseDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            
            for fileURL in files {
                let filename = fileURL.lastPathComponent.lowercased()
                let baseFilename = filename
                    .replacingOccurrences(of: ".plist", with: "")
                    .replacingOccurrences(of: ".savedstate", with: "")
                
                var isMatch = false
                if let bID = bundleIDLower, !bID.isEmpty {
                    if baseFilename == bID || filename.hasPrefix(bID + ".") {
                        isMatch = true
                    }
                }
                if !isMatch && appNameNormalized.count >= 3 {
                    if baseFilename == appNameNormalized ||
                       baseFilename.hasSuffix("." + appNameNormalized.replacingOccurrences(of: " ", with: "")) ||
                       baseFilename.hasSuffix("." + appNameNormalized.replacingOccurrences(of: " ", with: "-")) {
                        isMatch = true
                    }
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
