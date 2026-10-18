import Foundation

/// Scans the macOS user Trash directory (~/.Trash) to report items taking up disk space.
public final class TrashScanner: Scannable, Sendable {
    public let category: ScanCategory = .trash
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let trashURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        
        guard fileManager.fileExists(atPath: trashURL.path),
              fileManager.isReadableFile(atPath: trashURL.path) else {
            return []
        }
        
        let contents = (try? fileManager.contentsOfDirectory(
            at: trashURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [] // Do not skip hidden files in Trash
        )) ?? []
        
        for itemURL in contents {
            if Task.isCancelled { break }
            
            let size = ScannerHelper.size(of: itemURL)
            let modDate = ScannerHelper.modificationDate(of: itemURL)
            let item = ScannedItem(
                url: itemURL,
                displayName: itemURL.lastPathComponent,
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
