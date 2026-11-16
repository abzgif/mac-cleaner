import Foundation

/// Scans user diagnostic logs and crash reports while skipping active apps and protected tools.
public final class UserLogsScanner: Scannable, Sendable {
    public let category: ScanCategory = .userLogs
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        let targetDirectories: [URL] = [
            home.appendingPathComponent("Library/Logs"),
            home.appendingPathComponent("Library/Application Support/CrashReporter")
        ]
        
        for baseDir in targetDirectories {
            guard fileManager.fileExists(atPath: baseDir.path),
                  fileManager.isReadableFile(atPath: baseDir.path) else { continue }
            
            let contents = (try? fileManager.contentsOfDirectory(
                at: baseDir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            
            for itemURL in contents {
                if Task.isCancelled { break }
                
                if SafetyPolicy.shared.isProtectedCacheOrAppPath(itemURL.path) ||
                   SafetyPolicy.shared.isBelongingToRunningApp(path: itemURL.path) {
                    continue
                }
                
                let size = ScannerHelper.size(of: itemURL)
                guard size > 1024 * 10 else { continue }
                
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
        
        return results.sorted { $0.size > $1.size }
    }
}
