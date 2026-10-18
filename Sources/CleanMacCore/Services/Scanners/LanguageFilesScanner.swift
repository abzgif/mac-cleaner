import Foundation

/// Scans third-party applications for unused language localization directories (.lproj).
/// Marked as Advanced / High Risk because modifying app bundle contents may invalidate code signatures for apps with strict Gatekeeper checks.
public final class LanguageFilesScanner: Scannable, Sendable {
    public let category: ScanCategory = .languageFiles
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        
        // Only inspect third-party Applications, never System applications
        let appsURL = URL(fileURLWithPath: "/Applications")
        guard fileManager.fileExists(atPath: appsURL.path),
              fileManager.isReadableFile(atPath: appsURL.path) else {
            return []
        }
        
        // User's active system languages (e.g., "en", "en-US", "es")
        let preferredLanguages = Locale.preferredLanguages.map {
            $0.prefix(2).lowercased()
        }
        let keepLanguages: Set<String> = Set(preferredLanguages).union(["base", "en"])
        
        let appBundles = (try? fileManager.contentsOfDirectory(
            at: appsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        
        for appURL in appBundles where appURL.pathExtension == "app" {
            if Task.isCancelled { break }
            
            // Skip Apple system apps in /Applications
            let appName = appURL.lastPathComponent
            if appName.hasPrefix("Safari") || appName.hasPrefix("Apple") {
                continue
            }
            
            // Skip running apps
            if SafetyPolicy.shared.isBelongingToRunningApp(path: appURL.path) {
                continue
            }
            
            let resourcesURL = appURL.appendingPathComponent("Contents/Resources")
            guard fileManager.fileExists(atPath: resourcesURL.path),
                  let resources = try? fileManager.contentsOfDirectory(at: resourcesURL, includingPropertiesForKeys: nil) else {
                continue
            }
            
            for item in resources where item.pathExtension == "lproj" {
                let langCode = item.deletingPathExtension().lastPathComponent.lowercased()
                let cleanCode = String(langCode.prefix(2))
                
                // If not in the user's preferred languages
                if !keepLanguages.contains(cleanCode) && !keepLanguages.contains(langCode) {
                    let size = ScannerHelper.size(of: item)
                    guard size > 1024 else { continue }
                    
                    let scanned = ScannedItem(
                        url: item,
                        displayName: "\(appName) — \(item.lastPathComponent)",
                        size: size,
                        category: category,
                        modificationDate: ScannerHelper.modificationDate(of: item),
                        isSelected: false, // Never preselect high-risk files
                        parentAppName: appName,
                        riskWarning: "Advanced: Modifying app bundle internals may invalidate Gatekeeper code signature for this app."
                    )
                    results.append(scanned)
                    onFoundItem?(scanned)
                }
            }
        }
        
        return results
    }
}
