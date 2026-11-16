import Foundation

/// Scans the user's Downloads directory strictly for leftover macOS installer disk images and packages (.dmg, .pkg).
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
        
        let installerExtensions: Set<String> = ["dmg", "pkg"]
        
        let contents = (try? fileManager.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        
        for itemURL in contents {
            if Task.isCancelled { break }
            
            let ext = itemURL.pathExtension.lowercased()
            guard installerExtensions.contains(ext) else { continue }
            
            let size = ScannerHelper.size(of: itemURL)
            guard size > 1024 * 100 else { continue }
            
            let modDate = ScannerHelper.modificationDate(of: itemURL)
            let item = ScannedItem(
                url: itemURL,
                displayName: itemURL.lastPathComponent,
                size: size,
                category: category,
                modificationDate: modDate,
                isSelected: false, // Default unchecked so user reviews installers before removal
                riskWarning: "macOS Installer (\(ext.uppercased()))"
            )
            results.append(item)
            onFoundItem?(item)
        }
        
        return results.sorted { $0.size > $1.size }
    }
}
