import Foundation

/// Scans user diagnostic logs, crash reports, and system log directories.
public final class UserLogsScanner: Scannable, Sendable {
    public let category: ScanCategory = .userLogs
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        let targetDirectories: [URL] = [
            home.appendingPathComponent("Library/Logs"),
            URL(fileURLWithPath: "/Library/Logs"),
            home.appendingPathComponent("Library/Application Support/CrashReporter")
        ]
        
        for baseDir in targetDirectories {
            guard fileManager.fileExists(atPath: baseDir.path) else { continue }
            
            guard fileManager.isReadableFile(atPath: baseDir.path) else {
                let errorItem = ScannedItem(
                    url: baseDir,
                    displayName: "\(baseDir.lastPathComponent) (Restricted)",
                    size: 0,
                    category: category,
                    isSelected: false,
                    accessError: "Full Disk Access needed to scan this log directory"
                )
                results.append(errorItem)
                onFoundItem?(errorItem)
                continue
            }
            
            let contents = (try? fileManager.contentsOfDirectory(
                at: baseDir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            
            for itemURL in contents {
                if Task.isCancelled { break }
                
                let size = ScannerHelper.size(of: itemURL)
                guard size > 1024 else { continue } // Skip empty files
                
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
