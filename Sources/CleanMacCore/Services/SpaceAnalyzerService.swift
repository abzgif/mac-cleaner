import Foundation

/// Analyzes storage distribution across directories and builds a drillable space tree.
public final class SpaceAnalyzerService: Sendable {
    public static let shared = SpaceAnalyzerService()
    
    public init() {}
    
    /// Analyzes the direct contents of a directory and computes their sizes.
    public func analyzeDirectory(at directoryURL: URL) async -> SpaceItem {
        return await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey, .nameKey, .isPackageKey]
            
            guard let contents = try? fm.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            ) else {
                return SpaceItem(name: directoryURL.lastPathComponent, url: directoryURL, size: 0, isDirectory: true)
            }
            
            var childNodes: [SpaceItem] = []
            var totalDirectorySize: Int64 = 0
            
            for childURL in contents {
                guard let values = try? childURL.resourceValues(forKeys: Set(keys)) else { continue }
                let isDir = (values.isDirectory ?? false) && !(values.isPackage ?? false)
                let name = values.name ?? childURL.lastPathComponent
                
                let size: Int64
                if isDir {
                    size = self.calculateFolderSize(at: childURL)
                } else {
                    size = Int64(values.fileSize ?? 0)
                }
                
                totalDirectorySize += size
                let node = SpaceItem(name: name, url: childURL, size: size, isDirectory: isDir)
                childNodes.append(node)
            }
            
            // Sort children descending by size
            childNodes.sort { $0.size > $1.size }
            
            // Compute percentage relative to total
            let nonZeroTotal = max(totalDirectorySize, 1)
            for idx in childNodes.indices {
                childNodes[idx].percentage = Double(childNodes[idx].size) / Double(nonZeroTotal)
            }
            
            return SpaceItem(
                name: directoryURL.lastPathComponent.isEmpty ? "/" : directoryURL.lastPathComponent,
                url: directoryURL,
                size: totalDirectorySize,
                isDirectory: true,
                children: childNodes,
                percentage: 1.0
            )
        }.value
    }
    
    /// Calculates the total recursive size of a directory.
    private func calculateFolderSize(at folderURL: URL) -> Int64 {
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }
        
        var total: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  !(values.isDirectory ?? false) else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        
        return total
    }
}
