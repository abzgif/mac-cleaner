import Foundation

/// Scans user and system cache directories (~/Library/Caches and /Library/Caches).
public final class SystemCachesScanner: Scannable, Sendable {
    public let category: ScanCategory = .systemCaches
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        let targetDirectories: [URL] = [
            home.appendingPathComponent("Library/Caches"),
            URL(fileURLWithPath: "/Library/Caches")
        ]
        
        for baseDir in targetDirectories {
            guard fileManager.fileExists(atPath: baseDir.path) else { continue }
            
            // Check read permission
            guard fileManager.isReadableFile(atPath: baseDir.path) else {
                let errorItem = ScannedItem(
                    url: baseDir,
                    displayName: "\(baseDir.lastPathComponent) (Permission Denied)",
                    size: 0,
                    category: category,
                    isSelected: false,
                    accessError: "Requires elevated permission or Full Disk Access"
                )
                results.append(errorItem)
                onFoundItem?(errorItem)
                continue
            }
            
            let contents = (try? fileManager.contentsOfDirectory(
                at: baseDir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            
            for itemURL in contents {
                if Task.isCancelled { break }
                
                // Never delete running app caches or protected root components
                if SafetyPolicy.shared.isBelongingToRunningApp(path: itemURL.path) {
                    continue
                }
                
                let size = ScannerHelper.size(of: itemURL)
                guard size > 1024 * 50 else { continue } // Skip sub-50KB noise
                
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
        }
        
        return results
    }
}
