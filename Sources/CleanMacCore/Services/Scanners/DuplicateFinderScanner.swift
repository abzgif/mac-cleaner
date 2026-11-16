import Foundation

/// Two-stage duplicate file scanner: groups files by byte size first, then calculates SHA-256 hashes to find true duplicates while skipping development/project trees.
public final class DuplicateFinderScanner: Scannable, Sendable {
    public let category: ScanCategory = .duplicates
    public let targetDirectories: [URL]
    
    private static let skippedFolderNames: Set<String> = [
        ".git", ".build", "build", "node_modules", "Pods", "DerivedData",
        ".gradle", ".idea", "AndroidStudioProjects", "JDownloader", "JDownloader 2"
    ]
    
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
        
        for dir in targetDirectories {
            guard fileManager.fileExists(atPath: dir.path),
                  fileManager.isReadableFile(atPath: dir.path) else { continue }
            
            guard let enumerator = fileManager.enumerator(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isDirectoryKey],
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
                
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      let isRegular = resourceValues.isRegularFile, isRegular,
                      let fileSize = resourceValues.fileSize,
                      fileSize > 1024 else {
                    continue
                }
                
                sizeMap[Int64(fileSize), default: []].append(fileURL)
            }
        }
        
        let candidatesBySize = sizeMap.filter { $0.value.count > 1 }
        var results: [ScannedItem] = []
        
        for (size, urls) in candidatesBySize {
            if Task.isCancelled { break }
            
            var hashMap: [String: [URL]] = [:]
            
            for url in urls {
                if Task.isCancelled { break }
                guard let hash = HashUtility.sha256(of: url) else { continue }
                hashMap[hash, default: []].append(url)
            }
            
            for (hash, duplicateURLs) in hashMap where duplicateURLs.count > 1 {
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
                        isSelected: !isOriginal,
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
