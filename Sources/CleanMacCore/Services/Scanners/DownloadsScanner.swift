import Foundation

/// Scans the user's Downloads directory for old files and leftover installer packages (.dmg, .pkg, .iso).
public final class DownloadsScanner: Scannable, Sendable {
    public let category: ScanCategory = .downloads
    public let ageThresholdDays: Int
    
    public init(ageThresholdDays: Int = 30) {
        self.ageThresholdDays = ageThresholdDays
    }
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let downloadsURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        
        guard fileManager.fileExists(atPath: downloadsURL.path),
              fileManager.isReadableFile(atPath: downloadsURL.path) else {
            return []
        }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -ageThresholdDays, to: Date()) ?? Date()
        let installerExtensions: Set<String> = ["dmg", "pkg", "iso", "tar", "gz", "zip"]
        
        let contents = (try? fileManager.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        
        for itemURL in contents {
            if Task.isCancelled { break }
            
            let ext = itemURL.pathExtension.lowercased()
            let modDate = ScannerHelper.modificationDate(of: itemURL) ?? Date.distantPast
            let isInstaller = installerExtensions.contains(ext)
            let isOlderThanThreshold = modDate < cutoffDate
            
            // Flag if either it is an installer package or older than threshold
            if isInstaller || isOlderThanThreshold {
                let size = ScannerHelper.size(of: itemURL)
                guard size > 1024 * 10 else { continue } // Skip tiny files
                
                let warning = isOlderThanThreshold ? "Not modified in >\(ageThresholdDays) days" : "Installer Package"
                let item = ScannedItem(
                    url: itemURL,
                    displayName: itemURL.lastPathComponent,
                    size: size,
                    category: category,
                    modificationDate: modDate,
                    isSelected: false, // Default unchecked for safety since Downloads contains user files
                    riskWarning: warning
                )
                results.append(item)
                onFoundItem?(item)
            }
        }
        
        return results
    }
}
