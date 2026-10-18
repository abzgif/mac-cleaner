import Foundation

/// Two-stage duplicate file scanner: groups files by byte size first, then calculates SHA-256 hashes to find true duplicates.
public final class DuplicateFinderScanner: Scannable, Sendable {
    public let category: ScanCategory = .duplicates
    public let targetDirectories: [URL]
    
    public init(directories: [URL]? = nil) {
        if let dirs = directories {
            self.targetDirectories = dirs
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.targetDirectories = [
                home.appendingPathComponent("Downloads"),
                home.appendingPathComponent("Documents")
            ]
        }
    }
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        let fileManager = FileManager.default
        var sizeMap: [Int64: [URL]] = [:]
        
        // Stage 1: Enumerate and group files by size
        for dir in targetDirectories {
            guard fileManager.fileExists(atPath: dir.path),
                  fileManager.isReadableFile(atPath: dir.path) else { continue }
            
            guard let enumerator = fileManager.enumerator(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }
            
            while let fileURL = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }
                
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      let isRegular = resourceValues.isRegularFile, isRegular,
                      let fileSize = resourceValues.fileSize,
                      fileSize > 1024 else { // Ignore 0-byte or trivial files
                    continue
                }
                
                sizeMap[Int64(fileSize), default: []].append(fileURL)
            }
        }
        
        // Filter out sizes with only 1 file
        let candidatesBySize = sizeMap.filter { $0.value.count > 1 }
        
        var results: [ScannedItem] = []
        
        // Stage 2: Hash files with identical sizes
        for (size, urls) in candidatesBySize {
            if Task.isCancelled { break }
            
            var hashMap: [String: [URL]] = [:]
            
            for url in urls {
                if Task.isCancelled { break }
                guard let hash = HashUtility.sha256(of: url) else { continue }
                hashMap[hash, default: []].append(url)
            }
            
            // For hashes with >1 file, we have duplicates!
            for (hash, duplicateURLs) in hashMap where duplicateURLs.count > 1 {
                // Sort by modification date so the oldest is treated as the original
                let sortedURLs = duplicateURLs.sorted { u1, u2 in
                    let d1 = ScannerHelper.modificationDate(of: u1) ?? Date.distantPast
                    let d2 = ScannerHelper.modificationDate(of: u2) ?? Date.distantPast
                    return d1 < d2
                }
                
                for (index, fileURL) in sortedURLs.enumerated() {
                    let isOriginal = (index == 0)
                    let modDate = ScannerHelper.modificationDate(of: fileURL)
                    let item = ScannedItem(
                        url: fileURL,
                        displayName: fileURL.lastPathComponent,
                        size: size,
                        category: category,
                        modificationDate: modDate,
                        isSelected: !isOriginal, // Auto-select duplicates for removal, keep original unchecked
                        duplicateGroupId: hash,
                        riskWarning: isOriginal ? "Original file (recommended to keep)" : "Exact duplicate"
                    )
                    results.append(item)
                    onFoundItem?(item)
                }
            }
        }
        
        return results
    }
}
