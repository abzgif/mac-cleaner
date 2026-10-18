import Foundation

/// Scans cache directories for major web browsers (Safari, Chrome, Firefox, Edge, Arc, Brave).
public final class BrowserCachesScanner: Scannable, Sendable {
    public let category: ScanCategory = .browserCaches
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        // Known browser cache locations
        let browserLocations: [(name: String, path: URL)] = [
            ("Safari Cache", home.appendingPathComponent("Library/Caches/com.apple.Safari")),
            ("Google Chrome Cache", home.appendingPathComponent("Library/Caches/Google/Chrome/Default/Cache")),
            ("Google Chrome Code Cache", home.appendingPathComponent("Library/Caches/Google/Chrome/Default/Code Cache")),
            ("Firefox Cache", home.appendingPathComponent("Library/Caches/Firefox/Profiles")),
            ("Microsoft Edge Cache", home.appendingPathComponent("Library/Caches/Microsoft Edge/Default/Cache")),
            ("Brave Browser Cache", home.appendingPathComponent("Library/Caches/BraveSoftware/Brave-Browser/Default/Cache")),
            ("Arc Browser Cache", home.appendingPathComponent("Library/Caches/company.thebrowser.Browser"))
        ]
        
        for browser in browserLocations {
            guard fileManager.fileExists(atPath: browser.path.path) else { continue }
            
            // If browser is currently open, skip to avoid file lock conflicts or session loss
            if SafetyPolicy.shared.isBelongingToRunningApp(path: browser.path.path) {
                continue
            }
            
            guard fileManager.isReadableFile(atPath: browser.path.path) else {
                let errorItem = ScannedItem(
                    url: browser.path,
                    displayName: "\(browser.name) (Locked)",
                    size: 0,
                    category: category,
                    isSelected: false,
                    accessError: "Access locked by browser or permissions"
                )
                results.append(errorItem)
                onFoundItem?(errorItem)
                continue
            }
            
            let size = ScannerHelper.size(of: browser.path)
            guard size > 1024 * 100 else { continue } // Skip if under 100KB
            
            let modDate = ScannerHelper.modificationDate(of: browser.path)
            let item = ScannedItem(
                url: browser.path,
                displayName: browser.name,
                size: size,
                category: category,
                modificationDate: modDate,
                isSelected: true
            )
            results.append(item)
            onFoundItem?(item)
        }
        
        return results
    }
}
