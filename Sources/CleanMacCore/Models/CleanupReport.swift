import Foundation

/// Represents the audit record of a completed cleanup session.
public struct CleanupReport: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let bytesFreed: Int64
    public let fileCount: Int
    public let categoriesCleaned: [ScanCategory]
    public let trashedItemPaths: [String]
    public let permanentDeletion: Bool
    public var isUndone: Bool
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        bytesFreed: Int64,
        fileCount: Int,
        categoriesCleaned: [ScanCategory],
        trashedItemPaths: [String],
        permanentDeletion: Bool = false,
        isUndone: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.bytesFreed = bytesFreed
        self.fileCount = fileCount
        self.categoriesCleaned = categoriesCleaned
        self.trashedItemPaths = trashedItemPaths
        self.permanentDeletion = permanentDeletion
        self.isUndone = isUndone
    }
    
    public var formattedBytesFreed: String {
        ByteFormatter.format(bytesFreed)
    }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
