import Foundation

/// Scans user folders for large files exceeding a size threshold while skipping code repositories and app bundles.
public final class LargeOldFilesScanner: Scannable, Sendable {
    public let category: ScanCategory = .largeOldFiles
    public let minSizeBytes: Int64
    public let minAgeDays: Int
    
    private static let skippedFolderNames: Set<String> = [
        ".git", ".build", "build", "node_modules", "Pods", "DerivedData",
        ".gradle", ".idea", "AndroidStudioProjects", "JDownloader", "JDownloader 2"
    ]
    
    public init(minSizeMB: Int = 50, minAgeDays: Int = 90) {
        self.minSizeBytes = Int64(minSizeMB) * 1024 * 1024
        self.minAgeDays = minAgeDays
    }
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        let searchDirectories = [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Movies"),
            home.appendingPathComponent("Desktop")
        ]
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -minAgeDays, to: Date()) ?? Date()
        
        for dir in searchDirectories {
            guard fileManager.fileExists(atPath: dir.path),
                  fileManager.isReadableFile(atPath: dir.path) else { continue }
            
            guard let enumerator = fileManager.enumerator(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }
            
            while let fileURL = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }
                
                let name = fileURL.lastPathComponent
                if Self.skippedFolderNames.contains(name) || fileURL.pathExtension.lowercased() == "app" {
                    enumerator.skipDescendants()
                    continue
                }
                
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
                      let isRegular = resourceValues.isRegularFile, isRegular,
                      let fileSize = resourceValues.fileSize,
                      Int64(fileSize) >= minSizeBytes,
                      let modDate = resourceValues.contentModificationDate,
                      modDate <= cutoffDate else {
                    continue
                }
                
                let daysAgo = Calendar.current.dateComponents([.day], from: modDate, to: Date()).day ?? minAgeDays
                let item = ScannedItem(
                    url: fileURL,
                    displayName: fileURL.lastPathComponent,
                    size: Int64(fileSize),
                    category: category,
                    modificationDate: modDate,
                    isSelected: false,
                    riskWarning: "Not modified in \(daysAgo) days"
                )
                results.append(item)
                onFoundItem?(item)
            }
        }
        
        return results.sorted { $0.size > $1.size }
    }
}
