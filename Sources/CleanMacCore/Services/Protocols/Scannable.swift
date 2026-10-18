import Foundation

/// Protocol defining the contract for category-specific file scanners.
public protocol Scannable: Sendable {
    /// The specific category of system junk this scanner inspects.
    var category: ScanCategory { get }
    
    /// Executes the scan asynchronously, streaming found items via a progress closure.
    ///
    /// - Parameter onFoundItem: Closure called whenever a matching junk item is discovered.
    /// - Returns: Complete list of all discovered scanned items.
    func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem]
}

/// Helper methods for scanners to calculate folder sizes and inspect filesystem metadata safely.
public enum ScannerHelper {
    
    /// Calculates the cumulative disk size of a file or directory tree in bytes.
    public static func size(of url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return 0
        }
        
        if !isDir.boolValue {
            // Single file
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                return size
            }
            return 0
        }
        
        // Directory traversal
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsPackageDescendants, .skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  let isRegular = resourceValues.isRegularFile, isRegular,
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        
        return totalSize
    }
    
    /// Retrieves the last modification date of an item.
    public static func modificationDate(of url: URL) -> Date? {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let date = attrs[.modificationDate] as? Date {
            return date
        }
        return nil
    }
}
