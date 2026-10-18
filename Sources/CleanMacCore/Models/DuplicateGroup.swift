import Foundation

/// A cluster of identical files sharing the same size and SHA-256 hash.
public struct DuplicateGroup: Identifiable, Sendable {
    public let id: String // Hash string
    public let hash: String
    public let fileSize: Int64
    public var files: [ScannedItem]
    
    public init(hash: String, fileSize: Int64, files: [ScannedItem]) {
        self.id = hash
        self.hash = hash
        self.fileSize = fileSize
        self.files = files
    }
    
    /// Total potential space saved if all but one copy are deleted.
    public var reclaimableSize: Int64 {
        let duplicateCount = max(0, files.count - 1)
        return Int64(duplicateCount) * fileSize
    }
    
    public var formattedReclaimableSize: String {
        ByteFormatter.format(reclaimableSize)
    }
    
    public var formattedFileSize: String {
        ByteFormatter.format(fileSize)
    }
}
